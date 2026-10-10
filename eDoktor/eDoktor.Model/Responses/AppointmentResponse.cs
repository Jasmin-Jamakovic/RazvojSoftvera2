using System;

namespace eDoktor.Model.Responses
{
    public class AppointmentResponse
    {
        public int Id { get; set; }
        public int PatientId { get; set; }
        public string? PatientName { get; set; }
        public int DoctorId { get; set; }
        public string? DoctorName { get; set; }
        public int TimeSlotId { get; set; }
        public DateTime StartUtc { get; set; }
        public DateTime EndUtc { get; set; }
        public int Type { get; set; }
        public string TypeName => Type == 1 ? "Online" : "InPerson";
        // Pending / Confirmed / Completed / Cancelled
        public string Status { get; set; } = "Pending";
        public decimal Price { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? ConfirmedAt { get; set; }
        // Null while ConfirmedAt is set means "confirmed automatically after payment".
        public string? ConfirmedByName { get; set; }
        public DateTime? CompletedAt { get; set; }
        public string? CompletedByName { get; set; }
        public DateTime? CancelledAt { get; set; }
        public string? CancelledByName { get; set; }
        public string? CancellationReason { get; set; }
        public DateTime? RescheduledAt { get; set; }
        public string? RescheduledByName { get; set; }
        public string? RescheduleReason { get; set; }
        public PaymentResponse? Payment { get; set; }
        // Explicit paid flag so the client can hide the pay button without inspecting payment internals.
        public bool IsPaid => Payment != null && Payment.Status == PaymentStatus.Captured;
        public string? VideoRoomId { get; set; }
        // Rating the patient gave for this appointment; null when not reviewed yet.
        public int? ReviewRating { get; set; }
    }
}
