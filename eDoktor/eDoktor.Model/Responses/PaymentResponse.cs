using System;

namespace eDoktor.Model.Responses
{
    public class PaymentResponse
    {
        public int Id { get; set; }
        public int AppointmentId { get; set; }
        public string OrderId { get; set; } = string.Empty;
        public string? CaptureId { get; set; }
        public decimal Amount { get; set; }
        public string Currency { get; set; } = "EUR";
        public string Status { get; set; } = "Created";
        public DateTime CreatedAt { get; set; }
        public DateTime? CapturedAt { get; set; }
        public DateTime? RefundedAt { get; set; }

        // Filled only by the payment list endpoint (transaction overview).
        public string? PatientName { get; set; }
        public string? DoctorName { get; set; }
        public DateTime? AppointmentStartUtc { get; set; }
        public string? AppointmentStatus { get; set; }
    }
}
