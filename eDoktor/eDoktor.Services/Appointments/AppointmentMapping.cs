using System;
using System.Linq;
using eDoktor.Model;
using eDoktor.Model.Responses;
using eDoktor.Services.Database.Entities;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.Appointments
{
    // Single place that loads an appointment with everything its response needs and maps it,
    // shared by the appointment service and every state of the state machine.
    public static class AppointmentMapping
    {
        public static IQueryable<Appointment> WithDetails(this IQueryable<Appointment> q) => q
            .Include(a => a.Patient)
            .Include(a => a.Doctor).ThenInclude(d => d.User)
            .Include(a => a.TimeSlot)
            .Include(a => a.Payments)
            .Include(a => a.VideoCallSession)
            .Include(a => a.Review)
            .Include(a => a.ConfirmedBy)
            .Include(a => a.CompletedBy)
            .Include(a => a.CancelledBy)
            .Include(a => a.RescheduledBy);

        public static AppointmentResponse ToResponse(this Appointment a, IMapper mapper) => new()
        {
            Id = a.Id,
            PatientId = a.PatientId,
            PatientName = $"{a.Patient?.FirstName} {a.Patient?.LastName}",
            DoctorId = a.DoctorId,
            DoctorName = $"{a.Doctor?.User?.FirstName} {a.Doctor?.User?.LastName}",
            TimeSlotId = a.TimeSlotId,
            StartUtc = a.TimeSlot?.StartUtc ?? DateTime.MinValue,
            EndUtc = a.TimeSlot?.EndUtc ?? DateTime.MinValue,
            Type = (int)a.Type,
            Status = a.StateMachine.Replace("AppointmentState", string.Empty),
            Price = a.Price,
            CreatedAt = a.CreatedAt,
            ConfirmedAt = a.ConfirmedAt,
            ConfirmedByName = FullName(a.ConfirmedBy),
            CompletedAt = a.CompletedAt,
            CompletedByName = FullName(a.CompletedBy),
            CancelledAt = a.CancelledAt,
            CancelledByName = FullName(a.CancelledBy),
            CancellationReason = a.CancellationReason,
            RescheduledAt = a.RescheduledAt,
            RescheduledByName = FullName(a.RescheduledBy),
            RescheduleReason = a.RescheduleReason,
            Payment = a.CurrentPayment() is { } p ? mapper.Map<PaymentResponse>(p) : null,
            VideoRoomId = a.VideoCallSession?.RoomId,
            ReviewRating = a.Review is { IsDeleted: false } ? a.Review.Rating : null
        };

        /// The payment that describes the appointment: a settled (captured/refunded) one if there is one,
        /// otherwise the most recent order. Old cancelled/retried orders stay in the history only.
        public static PayPalPayment? CurrentPayment(this Appointment a) => a.Payments
            .OrderByDescending(p => p.Status == PaymentStatus.Captured || p.Status == PaymentStatus.Refunded)
            .ThenByDescending(p => p.CreatedAt)
            .FirstOrDefault();

        /// The captured (paid and not refunded) payment, if any.
        public static PayPalPayment? CapturedPayment(this Appointment a)
            => a.Payments.FirstOrDefault(p => p.Status == PaymentStatus.Captured);

        private static string? FullName(User? u) => u == null ? null : $"{u.FirstName} {u.LastName}";
    }
}
