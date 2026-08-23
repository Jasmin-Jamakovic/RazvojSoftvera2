using eDoktor.Model;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    public class PayPalPayment
    {
        public int Id { get; set; }

        public int AppointmentId { get; set; }

        [Required]
        [MaxLength(100)]
        public string OrderId { get; set; } = string.Empty;

        [MaxLength(100)]
        public string? CaptureId { get; set; }

        [Column(TypeName = "decimal(10,2)")]
        public decimal Amount { get; set; }

        [Required]
        [MaxLength(3)]
        public string Currency { get; set; } = "EUR";

        // Created, Approved, Captured, Refunded, Failed
        [Required]
        [MaxLength(20)]
        public string Status { get; set; } = PaymentStatus.Created;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime? CapturedAt { get; set; }

        public DateTime? RefundedAt { get; set; }
    }
}
