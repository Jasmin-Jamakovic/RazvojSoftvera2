using eDoktor.Model;
using System;
using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model.Responses;
using eDoktor.Services.AppointmentStateMachine;
using eDoktor.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.Dashboard
{
    public class DashboardService : IDashboardService
    {
        private readonly eDoktorDbContext _db;
        public DashboardService(eDoktorDbContext db) { _db = db; }

        public async Task<DashboardStatsResponse> GetStatsAsync(int? year = null, int? month = null, int? specializationId = null)
        {
            var totalDoctors = await _db.Doctors.CountAsync(d => !d.IsDeleted);
            var totalPatients = await _db.Users.CountAsync(u => !u.IsDeleted && u.Role.Name == Roles.Patient);
            var totalAppointments = await _db.Appointments.CountAsync();
            var today = DateTime.UtcNow.Date;
            var appointmentsToday = await _db.Appointments.CountAsync(a => a.TimeSlot.StartUtc >= today && a.TimeSlot.StartUtc < today.AddDays(1));

            var y = year ?? DateTime.UtcNow.Year;
            var m = month ?? DateTime.UtcNow.Month;
            var monthStart = new DateTime(y, m, 1);
            var monthEnd = monthStart.AddMonths(1);

            var monthlyRevenue = await _db.PayPalPayments
                .Where(p => p.Status == PaymentStatus.Captured && p.CapturedAt >= monthStart && p.CapturedAt < monthEnd)
                .SumAsync(p => (decimal?)p.Amount) ?? 0m;

            var rowsQ = _db.Doctors.Where(d => !d.IsDeleted);
            if (specializationId.HasValue)
                rowsQ = rowsQ.Where(d => d.DoctorSpecializations.Any(ds => ds.SpecializationId == specializationId.Value));

            var rows = await rowsQ
                .Select(d => new DoctorRevenueRow
                {
                    DoctorId = d.Id,
                    DoctorName = d.User.FirstName + " " + d.User.LastName,
                    Specialization = d.DoctorSpecializations.Select(ds => ds.Specialization.Name).FirstOrDefault(),
                    AppointmentCount = d.Appointments.Count(a => a.StateMachine == nameof(CompletedAppointmentState)),
                    AverageRating = d.Reviews.Any(r => !r.IsDeleted)
                        ? d.Reviews.Where(r => !r.IsDeleted).Average(r => (double)r.Rating)
                        : 0,
                    Revenue = d.Appointments
                        .Where(a => a.Payment != null && a.Payment.Status == PaymentStatus.Captured)
                        .Sum(a => (decimal?)a.Payment!.Amount) ?? 0m
                })
                .OrderByDescending(x => x.Revenue)
                .ToListAsync();

            var topSpec = await _db.Appointments
                .GroupBy(a => a.Doctor.DoctorSpecializations.Select(ds => ds.Specialization.Name).FirstOrDefault())
                .OrderByDescending(g => g.Count())
                .Select(g => g.Key)
                .FirstOrDefaultAsync();

            var topRow = rows.OrderByDescending(r => r.AverageRating).FirstOrDefault();

            return new DashboardStatsResponse
            {
                TotalDoctors = totalDoctors,
                TotalPatients = totalPatients,
                TotalAppointments = totalAppointments,
                AppointmentsToday = appointmentsToday,
                RevenueThisMonth = monthlyRevenue,
                TopSpecialization = topSpec,
                TopDoctor = topRow?.DoctorName,
                TopDoctorRating = topRow?.AverageRating ?? 0,
                Rows = rows
            };
        }
    }
}
