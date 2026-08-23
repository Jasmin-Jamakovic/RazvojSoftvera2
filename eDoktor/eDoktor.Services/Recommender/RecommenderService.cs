using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using eDoktor.Model.Responses;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using eDoktor.Services.Doctors;
using eDoktor.Services.Redis;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.Recommender
{
    // Content-based recommender per the spec:
    //   score(d) = 0.50 * sim(p,d) + 0.25 * norm(rating(d)) + 0.15 * distDecay(d) + 0.10 * availability(d)
    // TF-IDF over the doctor corpus, cosine similarity between patient vector and each doctor vector.
    // Result cached in Redis under "recs:{patientId}" with 6h TTL; invalidated on new appointment / review.
    public class RecommenderService : IRecommenderService
    {
        private const double W_SIM = 0.50;
        private const double W_RATING = 0.25;
        private const double W_DIST = 0.15;
        private const double W_AVAIL = 0.10;
        private static readonly TimeSpan CacheTtl = TimeSpan.FromHours(6);

        // Small bilingual stopword list (BS + EN).
        private static readonly HashSet<string> Stopwords = new(StringComparer.OrdinalIgnoreCase)
        {
            "i","je","u","na","sa","za","od","do","o","koji","koja","koje","kao","ali","ili","ne","da","li","se","što","s",
            "the","a","an","of","in","on","at","by","for","and","or","not","to","is","are","be","with","as","this","that"
        };

        private readonly eDoktorDbContext _db;
        private readonly IRedisCacheService _cache;

        public RecommenderService(eDoktorDbContext db, IRedisCacheService cache) { _db = db; _cache = cache; }

        public async Task InvalidateAsync(int patientId) => await _cache.RemoveAsync(Key(patientId));
        private static string Key(int patientId) => $"recs:{patientId}";

        public async Task<List<DoctorResponse>> GetRecommendedAsync(int patientId, int n = 10)
        {
            var cached = await _cache.GetAsync<List<DoctorResponse>>(Key(patientId));
            if (cached != null && cached.Count > 0) return cached.Take(n).ToList();

            var patient = await _db.Users.FirstOrDefaultAsync(u => u.Id == patientId);
            var doctors = await _db.Doctors
                .Where(d => !d.IsDeleted)
                .Include(d => d.User)
                .Include(d => d.Clinic).ThenInclude(c => c.City)
                .Include(d => d.DoctorSpecializations).ThenInclude(ds => ds.Specialization)
                .Include(d => d.Reviews)
                .Include(d => d.TimeSlots)
                .ToListAsync();

            if (doctors.Count == 0) return new List<DoctorResponse>();

            // Build per-doctor token bags
            var doctorTokens = doctors.ToDictionary(d => d.Id, d => Tokenize(BuildDoctorText(d)));

            // IDF over corpus
            var df = new Dictionary<string, int>();
            foreach (var tokens in doctorTokens.Values)
            {
                foreach (var t in tokens.Keys) df[t] = df.GetValueOrDefault(t) + 1;
            }
            int N = doctors.Count;
            var idf = df.ToDictionary(kv => kv.Key, kv => Math.Log((1.0 + N) / (1.0 + kv.Value)) + 1.0);

            // Doctor TF-IDF vectors
            var doctorVecs = doctorTokens.ToDictionary(kv => kv.Key, kv => TfIdf(kv.Value, idf));

            // Patient profile text from history
            var patientText = await BuildPatientTextAsync(patientId);
            var patientTokens = Tokenize(patientText);
            var patientVec = patientTokens.Count == 0 ? new Dictionary<string, double>() : TfIdf(patientTokens, idf);

            // Compute weighted scores
            var threshold = DateTime.UtcNow.AddDays(7);
            var scored = doctors.Select(d =>
            {
                var sim = patientVec.Count == 0 ? 0.0 : Cosine(patientVec, doctorVecs[d.Id]);
                var avgRating = d.Reviews?.Any() == true ? d.Reviews.Where(r => !r.IsDeleted).Average(r => (double)r.Rating) : 0;
                var normRating = avgRating / 5.0;
                var dist = (patient?.Latitude, patient?.Longitude, d.Clinic?.Latitude, d.Clinic?.Longitude) switch
                {
                    (double pLat, double pLon, double cLat, double cLon) => HaversineKm(pLat, pLon, cLat, cLon),
                    _ => 0.0
                };
                var distDecay = Math.Exp(-dist / 25.0);
                var availability = d.TimeSlots?.Any(t => !t.IsBooked && t.StartUtc > DateTime.UtcNow && t.StartUtc <= threshold) == true ? 1.0 : 0.0;

                var score = W_SIM * sim + W_RATING * normRating + W_DIST * distDecay + W_AVAIL * availability;

                var reason = DominantReason(sim, normRating, distDecay, availability, d);
                var resp = DoctorService.Map(d);
                resp.RecommendationReason = reason;
                return (Score: score, Resp: resp);
            })
            .OrderByDescending(x => x.Score)
            .Select(x => x.Resp)
            .ToList();

            await _cache.SetAsync(Key(patientId), scored, CacheTtl);
            return scored.Take(n).ToList();
        }

        private async Task<string> BuildPatientTextAsync(int patientId)
        {
            var pieces = new List<string>();
            var apptDocs = await _db.Appointments
                .Where(a => a.PatientId == patientId)
                .Include(a => a.Doctor).ThenInclude(d => d.DoctorSpecializations).ThenInclude(ds => ds.Specialization)
                .Select(a => a.Doctor)
                .ToListAsync();
            foreach (var d in apptDocs.Distinct())
            {
                pieces.Add(d.Bio ?? string.Empty);
                pieces.AddRange(d.DoctorSpecializations.Select(ds => ds.Specialization?.Name ?? string.Empty));
            }
            var entries = await _db.MedicalRecordEntries
                .Where(e => e.MedicalRecord.PatientId == patientId)
                .Select(e => (e.Diagnosis ?? "") + " " + (e.Therapy ?? "") + " " + (e.Notes ?? ""))
                .ToListAsync();
            pieces.AddRange(entries);
            return string.Join(" ", pieces);
        }

        private static string BuildDoctorText(Doctor d)
        {
            var parts = new List<string>
            {
                d.Bio ?? string.Empty,
                d.Clinic?.City?.Name ?? string.Empty
            };
            parts.AddRange(d.DoctorSpecializations.Select(ds => ds.Specialization?.Name ?? string.Empty));
            return string.Join(" ", parts);
        }

        private static Dictionary<string, int> Tokenize(string text)
        {
            var tokens = new Dictionary<string, int>();
            if (string.IsNullOrWhiteSpace(text)) return tokens;
            foreach (Match m in Regex.Matches(text.ToLowerInvariant(), @"[a-zA-ZčćžšđČĆŽŠĐ]{3,}"))
            {
                var t = m.Value;
                if (Stopwords.Contains(t)) continue;
                tokens[t] = tokens.GetValueOrDefault(t) + 1;
            }
            return tokens;
        }

        private static Dictionary<string, double> TfIdf(Dictionary<string, int> tokens, Dictionary<string, double> idf)
        {
            var total = (double)tokens.Values.Sum();
            var vec = new Dictionary<string, double>(tokens.Count);
            foreach (var (t, c) in tokens)
            {
                if (!idf.TryGetValue(t, out var i)) continue;
                vec[t] = (c / total) * i;
            }
            return vec;
        }

        private static double Cosine(Dictionary<string, double> a, Dictionary<string, double> b)
        {
            if (a.Count == 0 || b.Count == 0) return 0;
            double dot = 0;
            foreach (var (k, v) in a)
                if (b.TryGetValue(k, out var bv)) dot += v * bv;
            var na = Math.Sqrt(a.Values.Sum(v => v * v));
            var nb = Math.Sqrt(b.Values.Sum(v => v * v));
            if (na == 0 || nb == 0) return 0;
            return dot / (na * nb);
        }

        private static double HaversineKm(double lat1, double lon1, double lat2, double lon2)
        {
            const double R = 6371.0;
            double Rad(double d) => d * Math.PI / 180.0;
            var dLat = Rad(lat2 - lat1);
            var dLon = Rad(lon2 - lon1);
            var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2)
                  + Math.Cos(Rad(lat1)) * Math.Cos(Rad(lat2)) * Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
            var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
            return R * c;
        }

        private static string DominantReason(double sim, double rating, double dist, double avail, Doctor d)
        {
            var contribs = new[]
            {
                (W_SIM * sim, "Preporučeno na osnovu vaših prethodnih posjeta i historije"),
                (W_RATING * rating, $"Visoko ocijenjen ljekar ({(d.Reviews?.Any() == true ? d.Reviews.Average(r => r.Rating) : 0):F1}/5)"),
                (W_DIST * dist, "Ljekar u vašoj blizini"),
                (W_AVAIL * avail, "Dostupan u narednih 7 dana")
            };
            return contribs.OrderByDescending(x => x.Item1).First().Item2;
        }
    }
}
