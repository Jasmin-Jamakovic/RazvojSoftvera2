using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Messages;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Auth;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using eDoktor.Services.RabbitMQ;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.Doctors
{
    public class DoctorService : IDoctorService
    {
        private readonly eDoktorDbContext _db;
        private readonly IPasswordHasher _hasher;
        private readonly IRabbitMQService _rabbit;

        public DoctorService(eDoktorDbContext db, IPasswordHasher hasher, IRabbitMQService rabbit)
        {
            _db = db; _hasher = hasher; _rabbit = rabbit;
        }

        public async Task<PagedResult<DoctorResponse>> GetAsync(DoctorSearchObject s)
        {
            var q = _db.Doctors
                .Include(d => d.User)
                .Include(d => d.Clinic).ThenInclude(c => c.City)
                .Include(d => d.DoctorSpecializations).ThenInclude(ds => ds.Specialization)
                .Include(d => d.Reviews)
                .Include(d => d.TimeSlots)
                .Where(d => !d.IsDeleted)
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(s.Name))
                q = q.Where(d => (d.User.FirstName + " " + d.User.LastName).Contains(s.Name));
            if (s.SpecializationId.HasValue)
                q = q.Where(d => d.DoctorSpecializations.Any(ds => ds.SpecializationId == s.SpecializationId.Value));
            if (s.ClinicId.HasValue)
                q = q.Where(d => d.ClinicId == s.ClinicId.Value);
            if (s.MaxPrice.HasValue)
                q = q.Where(d => d.ConsultationPrice <= s.MaxPrice.Value);

            s.Normalize();
            int? total = s.IncludeTotalCount ? await q.CountAsync() : null;
            q = q.Skip(s.Page!.Value * s.PageSize!.Value).Take(s.PageSize!.Value);
            var list = await q.ToListAsync();

            // Post-filter for things hard to do in EF
            var items = list.Select(d => Map(d)).ToList();
            if (s.MinRating.HasValue) items = items.Where(x => x.AverageRating >= s.MinRating.Value).ToList();
            if (s.HasSlotInNext7Days == true)
            {
                var threshold = DateTime.UtcNow.AddDays(7);
                var doctorIdsWithSlots = list
                    .Where(d => d.TimeSlots.Any(t => !t.IsBooked && t.StartUtc > DateTime.UtcNow && t.StartUtc <= threshold))
                    .Select(d => d.Id).ToHashSet();
                items = items.Where(x => doctorIdsWithSlots.Contains(x.Id)).ToList();
            }

            return new PagedResult<DoctorResponse> { Items = items, TotalCount = total };
        }

        public async Task<DoctorResponse?> GetByIdAsync(int id)
        {
            var d = await _db.Doctors
                .Include(d => d.User)
                .Include(d => d.Clinic).ThenInclude(c => c.City)
                .Include(d => d.DoctorSpecializations).ThenInclude(ds => ds.Specialization)
                .Include(d => d.Reviews)
                .FirstOrDefaultAsync(d => d.Id == id);
            if (d == null || d.IsDeleted) return null;
            return Map(d, includePhoto: true);
        }

        public async Task<DoctorResponse> CreateAsync(DoctorUpsertRequest req)
        {
            if (req.SpecializationIds.Count == 0) throw new UserException("At least one specialization is required");
            ValidatePhoto(req.ProfilePhoto);

            var clinic = await _db.Clinics.FirstOrDefaultAsync(c => c.Id == req.ClinicId && !c.IsDeleted)
                ?? throw new UserException("Clinic not found");

            var doctorRole = await _db.Roles.FirstAsync(r => r.Name == Roles.Doctor);

            var username = string.IsNullOrWhiteSpace(req.Username)
                ? $"dr.{req.FirstName.ToLowerInvariant()}.{req.LastName.ToLowerInvariant()}"
                : req.Username;
            var email = string.IsNullOrWhiteSpace(req.Email)
                ? $"{username}@edoktor.local"
                : req.Email;

            if (await _db.Users.AnyAsync(u => u.Username == username)) throw new UserException("Username already taken");
            if (await _db.Users.AnyAsync(u => u.Email == email)) throw new UserException("Email already used");

            var tempPassword = GenerateTempPassword();
            var user = new User
            {
                FirstName = req.FirstName,
                LastName = req.LastName,
                Username = username,
                Email = email,
                PhoneNumber = req.PhoneNumber,
                PasswordHash = _hasher.Hash(tempPassword),
                RoleId = doctorRole.Id,
                CreatedAt = DateTime.UtcNow
            };

            // User + Doctor + specialization rows are created as one atomic unit.
            int createdDoctorId;
            await using (var tx = await _db.Database.BeginTransactionAsync())
            {
                _db.Users.Add(user);
                await _db.SaveChangesAsync();

                var doctor = new Doctor
                {
                    UserId = user.Id,
                    ClinicId = req.ClinicId,
                    Bio = req.Bio,
                    YearsExperience = req.YearsExperience,
                    ConsultationPrice = req.ConsultationPrice,
                    ProfilePhoto = req.ProfilePhoto
                };
                _db.Doctors.Add(doctor);
                await _db.SaveChangesAsync();

                foreach (var sid in req.SpecializationIds.Distinct())
                    _db.DoctorSpecializations.Add(new DoctorSpecialization { DoctorId = doctor.Id, SpecializationId = sid });
                await _db.SaveChangesAsync();

                await tx.CommitAsync();

                createdDoctorId = doctor.Id;
            }

            await _rabbit.PublishAsync(QueueNames.DoctorCreated, new DoctorCreatedMessage
            {
                UserId = user.Id,
                Email = user.Email,
                FirstName = user.FirstName,
                LastName = user.LastName,
                Username = user.Username,
                TemporaryPassword = tempPassword
            });

            return (await GetByIdAsync(createdDoctorId))!;
        }

        public async Task<DoctorResponse> UpdateAsync(int id, DoctorUpsertRequest req)
        {
            var d = await _db.Doctors
                .Include(d => d.User)
                .Include(d => d.DoctorSpecializations)
                .FirstOrDefaultAsync(x => x.Id == id)
                ?? throw new UserException("Doctor not found");
            ValidatePhoto(req.ProfilePhoto);

            d.User.FirstName = req.FirstName;
            d.User.LastName = req.LastName;
            if (!string.IsNullOrWhiteSpace(req.PhoneNumber)) d.User.PhoneNumber = req.PhoneNumber;
            d.ClinicId = req.ClinicId;
            d.Bio = req.Bio;
            d.YearsExperience = req.YearsExperience;
            d.ConsultationPrice = req.ConsultationPrice;
            if (req.ProfilePhoto != null) d.ProfilePhoto = req.ProfilePhoto;

            // Replace specialization set
            _db.DoctorSpecializations.RemoveRange(d.DoctorSpecializations);
            foreach (var sid in req.SpecializationIds.Distinct())
                _db.DoctorSpecializations.Add(new DoctorSpecialization { DoctorId = d.Id, SpecializationId = sid });

            await _db.SaveChangesAsync();
            return (await GetByIdAsync(id))!;
        }

        public async Task<bool> SoftDeleteAsync(int id)
        {
            var d = await _db.Doctors.FirstOrDefaultAsync(x => x.Id == id);
            if (d == null) return false;
            d.IsDeleted = true;
            await _db.SaveChangesAsync();
            return true;
        }

        // Rejects a supplied photo unless its magic bytes are a supported image within the size limit.
        private static void ValidatePhoto(byte[]? photo)
        {
            if (photo != null && !ImageValidation.IsValidImage(photo))
                throw new UserException("Slika mora biti validna slika (PNG, JPEG, GIF ili WEBP) i manja od 5 MB.");
        }

        private static string GenerateTempPassword()
        {
            const string chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
            var rand = new Random();
            return new string(Enumerable.Range(0, 10).Select(_ => chars[rand.Next(chars.Length)]).ToArray());
        }

        internal static DoctorResponse Map(Doctor d, bool includePhoto = false)
        {
            var reviews = d.Reviews?.Where(r => !r.IsDeleted).ToList() ?? new List<Review>();
            return new DoctorResponse
            {
                Id = d.Id,
                UserId = d.UserId,
                FirstName = d.User?.FirstName ?? string.Empty,
                LastName = d.User?.LastName ?? string.Empty,
                Bio = d.Bio,
                YearsExperience = d.YearsExperience,
                ConsultationPrice = d.ConsultationPrice,
                ProfilePhoto = includePhoto ? d.ProfilePhoto : null,
                HasPhoto = d.ProfilePhoto != null && d.ProfilePhoto.Length > 0,
                Clinic = d.Clinic == null ? null : new ClinicResponse
                {
                    Id = d.Clinic.Id, Name = d.Clinic.Name, Address = d.Clinic.Address,
                    CityId = d.Clinic.CityId, CityName = d.Clinic.City?.Name,
                    Latitude = d.Clinic.Latitude, Longitude = d.Clinic.Longitude, IsDeleted = d.Clinic.IsDeleted
                },
                Specializations = d.DoctorSpecializations?
                    .Where(ds => ds.Specialization != null)
                    .Select(ds => new SpecializationResponse { Id = ds.Specialization.Id, Name = ds.Specialization.Name, Description = ds.Specialization.Description })
                    .ToList() ?? new(),
                AverageRating = reviews.Count == 0 ? 0 : reviews.Average(r => (double)r.Rating),
                ReviewCount = reviews.Count,
                IsDeleted = d.IsDeleted
            };
        }
    }
}
