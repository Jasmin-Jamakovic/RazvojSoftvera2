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
    // The patient vector comes from visit history, the ratings the patient gave and their searches.
    // Result cached in Redis under "recs:{patientId}" with 6h TTL; invalidated on booking, completed visit,
    // new review and new search.
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
            var profile = await BuildPatientProfileAsync(patientId);
            var patientTokens = Tokenize(profile.Text);
            var patientVec = patientTokens.Count == 0 ? new Dictionary<string, double>() : TfIdf(patientTokens, idf);

            // Compute weighted scores
            var threshold = DateTime.UtcNow.AddDays(7);
            var scored = doctors.Select(d =>
            {
                var sim = patientVec.Count == 0 ? 0.0 : Cosine(patientVec, doctorVecs[d.Id]);
                var avgRating = AverageRating(d);
                var normRating = avgRating / 5.0;
                double? dist = (patient?.Latitude, patient?.Longitude, d.Clinic?.Latitude, d.Clinic?.Longitude) switch
                {
                    (double pLat, double pLon, double cLat, double cLon) => HaversineKm(pLat, pLon, cLat, cLon),
                    _ => null
                };
                // Unknown location: no distance penalty (decay 1.0), but proximity is not used as the explanation.
                var distDecay = dist.HasValue ? Math.Exp(-dist.Value / 25.0) : 1.0;
                var availability = d.TimeSlots?.Any(t => !t.IsBooked && t.StartUtc > DateTime.UtcNow && t.StartUtc <= threshold) == true ? 1.0 : 0.0;

                var score = W_SIM * sim + W_RATING * normRating + W_DIST * distDecay + W_AVAIL * availability;

                var reason = DominantReason(sim, normRating, dist.HasValue ? distDecay : 0, availability, d, profile);
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

        private const int SearchHistoryDepth = 20;
        private const int LikedRating = 4;
        private const int DislikedRating = 2;

        private record PatientProfile(string Text, HashSet<string> SearchedSpecializations, HashSet<string> VisitedSpecializations);

        // Builds the patient's profile from real, recorded data:
        //  - doctors of past appointments (specializations + bio); a doctor the patient rated >= 4 counts twice,
        //    one rated <= 2 is left out, so the ratings the patient gave steer the profile;
        //  - diagnosis/therapy/notes from the medical record;
        //  - the latest searches (typed text + chosen specialization).
        private async Task<PatientProfile> BuildPatientProfileAsync(int patientId)
        {
            var pieces = new List<string>();
            var visited = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            var visits = await _db.Appointments
                .Where(a => a.PatientId == patientId)
                .Select(a => new
                {
                    a.DoctorId,
                    a.Doctor.Bio,
                    Specializations = a.Doctor.DoctorSpecializations.Select(ds => ds.Specialization.Name).ToList(),
                    Rating = a.Review != null && !a.Review.IsDeleted ? (int?)a.Review.Rating : null
                })
                .ToListAsync();
            foreach (var g in visits.GroupBy(v => v.DoctorId))
            {
                var ratings = g.Where(v => v.Rating.HasValue).Select(v => v.Rating!.Value).ToList();
                var avg = ratings.Count == 0 ? (double?)null : ratings.Average();
                if (avg <= DislikedRating) continue;
                var weight = avg >= LikedRating ? 2 : 1;
                var doctor = g.First();
                for (var i = 0; i < weight; i++)
                {
                    pieces.Add(doctor.Bio ?? string.Empty);
                    pieces.AddRange(doctor.Specializations);
                }
                foreach (var spec in doctor.Specializations) visited.Add(spec);
            }

            var entries = await _db.MedicalRecordEntries
                .Where(e => e.MedicalRecord.PatientId == patientId)
                .Select(e => (e.Diagnosis ?? "") + " " + (e.Therapy ?? "") + " " + (e.Notes ?? ""))
                .ToListAsync();
            pieces.AddRange(entries);

            var searches = await _db.SearchHistories
                .Where(h => h.UserId == patientId)
                .OrderByDescending(h => h.CreatedAt)
                .Take(SearchHistoryDepth)
                .Select(h => new { h.Query, Specialization = h.Specialization != null ? h.Specialization.Name : null })
                .ToListAsync();
            var searched = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var h in searches)
            {
                if (h.Query != null) pieces.Add(h.Query);
                if (h.Specialization != null) { pieces.Add(h.Specialization); searched.Add(h.Specialization); }
            }

            return new PatientProfile(string.Join(" ", pieces), searched, visited);
        }

        private static double AverageRating(Doctor d)
        {
            var active = d.Reviews?.Where(r => !r.IsDeleted).ToList();
            return active == null || active.Count == 0 ? 0 : active.Average(r => (double)r.Rating);
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

        private static string DominantReason(double sim, double rating, double dist, double avail, Doctor d, PatientProfile profile)
        {
            var specs = d.DoctorSpecializations.Select(ds => ds.Specialization?.Name).OfType<string>().ToList();
            var searchedSpec = specs.FirstOrDefault(profile.SearchedSpecializations.Contains);
            var visitedSpec = specs.FirstOrDefault(profile.VisitedSpecializations.Contains);
            var similarity = searchedSpec != null ? $"Odgovara vašim nedavnim pretragama ({searchedSpec})"
                : visitedSpec != null ? $"Preporučeno na osnovu vaših prethodnih posjeta ({visitedSpec})"
                : "Preporučeno na osnovu vaše historije pregleda i pretraga";

            var contribs = new[]
            {
                (W_SIM * sim, similarity),
                (W_RATING * rating, $"Visoko ocijenjen ljekar ({AverageRating(d):F1}/5)"),
                (W_DIST * dist, "Ljekar u vašoj blizini"),
                (W_AVAIL * avail, "Dostupan u narednih 7 dana")
            };
            return contribs.OrderByDescending(x => x.Item1).First().Item2;
        }
    }
}
