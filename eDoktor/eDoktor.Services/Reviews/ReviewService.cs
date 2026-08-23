using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.AppointmentStateMachine;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using eDoktor.Services.Redis;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.Reviews
{
    public class ReviewService : IReviewService
    {
        private readonly eDoktorDbContext _db;
        private readonly IRedisCacheService _cache;
        public ReviewService(eDoktorDbContext db, IRedisCacheService cache) { _db = db; _cache = cache; }

        public async Task<PagedResult<ReviewResponse>> GetAsync(ReviewSearchObject s)
        {
            var q = _db.Reviews.Include(r => r.Patient).Where(r => !r.IsDeleted).AsQueryable();
            if (s.DoctorId.HasValue) q = q.Where(r => r.DoctorId == s.DoctorId.Value);
            if (s.PatientId.HasValue) q = q.Where(r => r.PatientId == s.PatientId.Value);
            q = q.OrderByDescending(r => r.CreatedAt);

            s.Normalize();
            int? total = s.IncludeTotalCount ? await q.CountAsync() : null;
            q = q.Skip(s.Page!.Value * s.PageSize!.Value).Take(s.PageSize!.Value);
            var list = await q.ToListAsync();
            return new PagedResult<ReviewResponse>
            {
                Items = list.Select(r => new ReviewResponse
                {
                    Id = r.Id, AppointmentId = r.AppointmentId, DoctorId = r.DoctorId, PatientId = r.PatientId,
                    PatientName = $"{r.Patient?.FirstName} {r.Patient?.LastName}",
                    Rating = r.Rating, Comment = r.Comment, CreatedAt = r.CreatedAt
                }).ToList(),
                TotalCount = total
            };
        }

        public async Task<ReviewResponse> CreateAsync(ReviewUpsertRequest req, int patientId)
        {
            var appt = await _db.Appointments.FirstOrDefaultAsync(a => a.Id == req.AppointmentId)
                ?? throw new UserException("Appointment not found");
            if (appt.PatientId != patientId) throw new UserException("Not your appointment");
            if (appt.StateMachine != nameof(CompletedAppointmentState))
                throw new UserException("You can only review a completed appointment");
            if (await _db.Reviews.AnyAsync(r => r.AppointmentId == req.AppointmentId && !r.IsDeleted))
                throw new UserException("Review already exists for this appointment");

            var r = new Review
            {
                AppointmentId = req.AppointmentId,
                DoctorId = appt.DoctorId,
                PatientId = patientId,
                Rating = req.Rating,
                Comment = req.Comment
            };
            _db.Reviews.Add(r);
            await _db.SaveChangesAsync();

            await _cache.RemoveAsync($"recs:{patientId}");

            return new ReviewResponse
            {
                Id = r.Id, AppointmentId = r.AppointmentId, DoctorId = r.DoctorId, PatientId = r.PatientId,
                Rating = r.Rating, Comment = r.Comment, CreatedAt = r.CreatedAt
            };
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var r = await _db.Reviews.FirstOrDefaultAsync(x => x.Id == id);
            if (r == null) return false;
            r.IsDeleted = true;
            await _db.SaveChangesAsync();
            return true;
        }
    }
}
