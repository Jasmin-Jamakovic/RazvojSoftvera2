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
            if (m < 1 || m > 12 || y < 2000 || y > 2100)
                throw new UserException("Neispravan mjesec ili godina.");
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

        public async Task<DoctorReportResponse> GetDoctorReportAsync(DateTime from, DateTime to, int? specializationId)
        {
            if (to <= from)
                throw new UserException("Kraj perioda mora biti nakon početka.");
            if ((to - from).TotalDays > 366)
                throw new UserException("Izvještaj se može generisati za period od najviše godinu dana.");

            string? specName = null;
            if (specializationId.HasValue)
            {
                specName = await _db.Specializations.Where(s => s.Id == specializationId.Value).Select(s => s.Name).FirstOrDefaultAsync()
                    ?? throw new NotFoundException("Specijalizacija nije pronađena.");
            }

            const string completed = nameof(CompletedAppointmentState);
            var doctors = _db.Doctors.Where(d => !d.IsDeleted);
            if (specializationId.HasValue)
                doctors = doctors.Where(d => d.DoctorSpecializations.Any(ds => ds.SpecializationId == specializationId.Value));

            // Exams = completed appointments held in the period; revenue = PayPal payments captured
            // in the period and not refunded; rating = the doctor's overall average from active reviews.
            var rows = await doctors
                .Select(d => new DoctorRevenueRow
                {
                    DoctorId = d.Id,
                    DoctorName = d.User.FirstName + " " + d.User.LastName,
                    Specialization = d.DoctorSpecializations.Select(ds => ds.Specialization.Name).FirstOrDefault(),
                    AppointmentCount = d.Appointments.Count(a => a.StateMachine == completed
                        && a.TimeSlot.StartUtc >= from && a.TimeSlot.StartUtc < to),
                    AverageRating = d.Reviews.Any(r => !r.IsDeleted)
                        ? d.Reviews.Where(r => !r.IsDeleted).Average(r => (double)r.Rating)
                        : 0,
                    Revenue = d.Appointments
                        .Where(a => a.Payment != null && a.Payment.Status == PaymentStatus.Captured
                            && a.Payment.CapturedAt >= from && a.Payment.CapturedAt < to)
                        .Sum(a => (decimal?)a.Payment!.Amount) ?? 0m
                })
                .OrderByDescending(r => r.AppointmentCount)
                .ThenByDescending(r => r.Revenue)
                .ToListAsync();

            var examsInPeriod = _db.Appointments.Where(a => a.StateMachine == completed
                && a.TimeSlot.StartUtc >= from && a.TimeSlot.StartUtc < to);
            if (specializationId.HasValue)
                examsInPeriod = examsInPeriod.Where(a => a.Doctor.DoctorSpecializations.Any(ds => ds.SpecializationId == specializationId.Value));

            var topSpec = await examsInPeriod
                .GroupBy(a => a.Doctor.DoctorSpecializations.Select(ds => ds.Specialization.Name).FirstOrDefault())
                .OrderByDescending(g => g.Count())
                .Select(g => g.Key)
                .FirstOrDefaultAsync();

            var topDoctor = rows.Where(r => r.AverageRating > 0)
                .OrderByDescending(r => r.AverageRating).ThenByDescending(r => r.AppointmentCount)
                .FirstOrDefault();

            return new DoctorReportResponse
            {
                From = from,
                To = to,
                SpecializationName = specName,
                TotalExams = rows.Sum(r => r.AppointmentCount),
                TotalRevenue = rows.Sum(r => r.Revenue),
                TopSpecialization = topSpec,
                TopDoctor = topDoctor?.DoctorName,
                TopDoctorRating = topDoctor?.AverageRating ?? 0,
                Rows = rows
            };
        }
    }
}
