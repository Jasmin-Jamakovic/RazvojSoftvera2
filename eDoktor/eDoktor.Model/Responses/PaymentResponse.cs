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
    }
}
