using eDoktor.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model.Responses;
using eDoktor.Services.AppointmentStateMachine;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.Dashboard
{
    // Money in every overview is counted the same way as in PaymentService.GetSummaryAsync:
    // gross by the capture date, refunds by the refund date, net = gross - refunds of the same period.
    // So a payment captured in one month and refunded in the next stays in the first month's gross.
    public class DashboardService : IDashboardService
    {
        private readonly eDoktorDbContext _db;
        public DashboardService(eDoktorDbContext db) { _db = db; }

        public async Task<DashboardStatsResponse> GetStatsAsync(int? year = null, int? month = null, int? specializationId = null)
        {
            var totalDoctors = await _db.Doctors.CountAsync(d => !d.IsDeleted);
            var totalPatients = await _db.Users.CountAsync(u => !u.IsDeleted && u.Role.Name == Roles.Patient);
            var totalAppointments = await _db.Appointments.CountAsync();
            // "Today" and the month are the clinic's local calendar, converted to UTC bounds for the queries.
            var localToday = DisplayTime.ToLocal(DateTime.UtcNow).Date;
            var todayStart = DisplayTime.ToUtc(localToday);
            var todayEnd = DisplayTime.ToUtc(localToday.AddDays(1));
            var appointmentsToday = await _db.Appointments.CountAsync(a => a.TimeSlot.StartUtc >= todayStart && a.TimeSlot.StartUtc < todayEnd);

            var y = year ?? localToday.Year;
            var m = month ?? localToday.Month;
            if (m < 1 || m > 12 || y < 2000 || y > 2100)
                throw new UserException("Neispravan mjesec ili godina.");
            var monthStart = DisplayTime.ToUtc(new DateTime(y, m, 1));
            var monthEnd = DisplayTime.ToUtc(new DateTime(y, m, 1).AddMonths(1));

            var gross = await GrossAsync(_db.PayPalPayments, monthStart, monthEnd);
            var refunds = await RefundsAsync(_db.PayPalPayments, monthStart, monthEnd);

            var specName = await SpecializationNameAsync(specializationId);
            var rows = await DoctorRowsAsync(specializationId, specName, monthStart, monthEnd, completedInPeriodOnly: false);
            rows = rows.OrderByDescending(x => x.Revenue).ToList();

            var topSpec = await TopSpecializationAsync(_db.Appointments, specializationId, specName);
            var topRow = rows.OrderByDescending(r => r.AverageRating).FirstOrDefault();

            return new DashboardStatsResponse
            {
                TotalDoctors = totalDoctors,
                TotalPatients = totalPatients,
                TotalAppointments = totalAppointments,
                AppointmentsToday = appointmentsToday,
                MonthStart = monthStart,
                MonthEnd = monthEnd,
                GrossThisMonth = gross,
                RefundsThisMonth = refunds,
                RevenueThisMonth = gross - refunds,
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

            var specName = await SpecializationNameAsync(specializationId);

            // Exams = completed appointments held in the period; money as described at the top of the class;
            // rating = the doctor's overall average from active reviews.
            var rows = (await DoctorRowsAsync(specializationId, specName, from, to, completedInPeriodOnly: true))
                .OrderByDescending(r => r.AppointmentCount)
                .ThenByDescending(r => r.Revenue)
                .ToList();

            const string completed = nameof(CompletedAppointmentState);
            var examsInPeriod = _db.Appointments.Where(a => a.StateMachine == completed
                && a.TimeSlot.StartUtc >= from && a.TimeSlot.StartUtc < to);
            var topSpec = await TopSpecializationAsync(examsInPeriod, specializationId, specName);

            var topDoctor = rows.Where(r => r.AverageRating > 0)
                .OrderByDescending(r => r.AverageRating).ThenByDescending(r => r.AppointmentCount)
                .FirstOrDefault();

            return new DoctorReportResponse
            {
                From = from,
                To = to,
                SpecializationName = specName,
                TotalExams = rows.Sum(r => r.AppointmentCount),
                TotalGross = rows.Sum(r => r.GrossRevenue),
                TotalRefunds = rows.Sum(r => r.Refunds),
                TotalRevenue = rows.Sum(r => r.Revenue),
                TopSpecialization = topSpec,
                TopDoctor = topDoctor?.DoctorName,
                TopDoctorRating = topDoctor?.AverageRating ?? 0,
                Rows = rows
            };
        }

        private async Task<string?> SpecializationNameAsync(int? specializationId)
        {
            if (!specializationId.HasValue) return null;
            return await _db.Specializations.Where(s => s.Id == specializationId.Value).Select(s => s.Name).FirstOrDefaultAsync()
                ?? throw new NotFoundException("Specijalizacija nije pronađena.");
        }

        // One row per active doctor (of the chosen specialization) with exams, rating and money for [from, to).
        private async Task<List<DoctorRevenueRow>> DoctorRowsAsync(int? specializationId, string? specName, DateTime from, DateTime to, bool completedInPeriodOnly)
        {
            const string completed = nameof(CompletedAppointmentState);
            var doctors = _db.Doctors.Where(d => !d.IsDeleted);
            if (specializationId.HasValue)
                doctors = doctors.Where(d => d.DoctorSpecializations.Any(ds => ds.SpecializationId == specializationId.Value));

            var rows = await doctors
                .Select(d => new DoctorRevenueRow
                {
                    DoctorId = d.Id,
                    DoctorName = d.User.FirstName + " " + d.User.LastName,
                    Specialization = d.DoctorSpecializations.OrderBy(ds => ds.Specialization.Name).Select(ds => ds.Specialization.Name).FirstOrDefault(),
                    AppointmentCount = completedInPeriodOnly
                        ? d.Appointments.Count(a => a.StateMachine == completed && a.TimeSlot.StartUtc >= from && a.TimeSlot.StartUtc < to)
                        : d.Appointments.Count(a => a.StateMachine == completed),
                    AverageRating = d.Reviews.Any(r => !r.IsDeleted)
                        ? d.Reviews.Where(r => !r.IsDeleted).Average(r => (double)r.Rating)
                        : 0,
                    GrossRevenue = d.Appointments.SelectMany(a => a.Payments)
                        .Where(p => p.CapturedAt != null && p.CapturedAt >= from && p.CapturedAt < to)
                        .Sum(p => (decimal?)p.Amount) ?? 0m,
                    Refunds = d.Appointments.SelectMany(a => a.Payments)
                        .Where(p => p.Status == PaymentStatus.Refunded && p.RefundedAt >= from && p.RefundedAt < to)
                        .Sum(p => (decimal?)p.Amount) ?? 0m
                })
                .ToListAsync();

            foreach (var r in rows)
            {
                r.Revenue = r.GrossRevenue - r.Refunds;
                // With a specialization filter the doctor is listed for that specialization, even when they also
                // have others, so the column shows the filtered one (the same in the table and the PDF).
                if (specName != null) r.Specialization = specName;
            }
            return rows;
        }

        // Most booked specialization. With a filter every counted appointment belongs to the chosen
        // specialization, so that is the answer (when there is anything to count).
        private static async Task<string?> TopSpecializationAsync(IQueryable<Appointment> appointments, int? specializationId, string? specName)
        {
            if (specializationId.HasValue)
            {
                var any = await appointments.AnyAsync(a => a.Doctor.DoctorSpecializations.Any(ds => ds.SpecializationId == specializationId.Value));
                return any ? specName : null;
            }
            return await appointments
                .GroupBy(a => a.Doctor.DoctorSpecializations.OrderBy(ds => ds.Specialization.Name).Select(ds => ds.Specialization.Name).FirstOrDefault())
                .OrderByDescending(g => g.Count())
                .Select(g => g.Key)
                .FirstOrDefaultAsync();
        }

        private static async Task<decimal> GrossAsync(IQueryable<PayPalPayment> payments, DateTime from, DateTime to) =>
            await payments.Where(p => p.CapturedAt != null && p.CapturedAt >= from && p.CapturedAt < to).SumAsync(p => (decimal?)p.Amount) ?? 0m;

        private static async Task<decimal> RefundsAsync(IQueryable<PayPalPayment> payments, DateTime from, DateTime to) =>
            await payments.Where(p => p.Status == PaymentStatus.Refunded && p.RefundedAt >= from && p.RefundedAt < to).SumAsync(p => (decimal?)p.Amount) ?? 0m;
    }
}
