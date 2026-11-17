using System;
using System.Linq;
using eDoktor.Model;
using eDoktor.Services.AppointmentStateMachine;
using eDoktor.Services.Database.Entities;

namespace eDoktor.Services.Payments
{
    // Payment rules shared by the API, the state machine and the background maintenance job,
    // so the server, the mobile app and the desktop app all follow the same deadline and refund conditions.
    public static class PaymentRules
    {
        /// How long a booked (Pending) paid appointment holds its slot while waiting for payment.
        public static readonly TimeSpan PaymentWindow = TimeSpan.FromHours(24);

        /// Cancellation at least this long before the appointment entitles the patient to a refund.
        public static readonly TimeSpan RefundCancellationNotice = TimeSpan.FromHours(24);

        /// The moment by which an appointment has to be paid: the payment window after booking,
        /// but never later than the appointment itself.
        public static DateTime PaymentDeadline(DateTime createdAtUtc, DateTime slotStartUtc)
        {
            var deadline = createdAtUtc + PaymentWindow;
            return deadline < slotStartUtc ? deadline : slotStartUtc;
        }

        /// True for an appointment that is still waiting to be paid (Pending, has a price, no settled payment).
        public static bool AwaitsPayment(Appointment a) =>
            a.StateMachine == nameof(PendingAppointmentState) && a.Price > 0
            && !a.Payments.Any(p => p.Status == PaymentStatus.Captured || p.Status == PaymentStatus.Refunded || p.Status == PaymentStatus.RefundPending);

        /// Admin refund condition from the topic application: the appointment is cancelled, and either the
        /// patient cancelled at least 24h before it, or the practice (doctor/admin) cancelled it, which always
        /// entitles the patient to their money back.
        public static bool RefundAllowed(Appointment a) =>
            a.StateMachine == nameof(CancelledAppointmentState)
            && a.CancelledAt.HasValue
            && (a.CancelledById != a.PatientId || a.CancelledAt.Value <= a.TimeSlot.StartUtc - RefundCancellationNotice);
    }
}
