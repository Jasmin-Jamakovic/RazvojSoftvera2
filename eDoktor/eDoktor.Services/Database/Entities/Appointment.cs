using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    public enum AppointmentType
    {
        InPerson = 0,
        Online = 1
    }

    public class Appointment
    {
        public int Id { get; set; }

        public int PatientId { get; set; }
        [ForeignKey(nameof(PatientId))]
        public virtual User Patient { get; set; } = null!;

        public int DoctorId { get; set; }
        [ForeignKey(nameof(DoctorId))]
        public virtual Doctor Doctor { get; set; } = null!;

        public int TimeSlotId { get; set; }
        [ForeignKey(nameof(TimeSlotId))]
        public virtual TimeSlot TimeSlot { get; set; } = null!;

        public AppointmentType Type { get; set; } = AppointmentType.InPerson;

        [Required]
        [MaxLength(40)]
        // Pending, Confirmed, Completed, Cancelled
        public string StateMachine { get; set; } = "PendingAppointmentState";

        [Column(TypeName = "decimal(10,2)")]
        public decimal Price { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Audit trail: who changed the status, when, and why. A null "By" on a confirmation means it
        // happened automatically after a successful PayPal payment.
        public DateTime? ConfirmedAt { get; set; }
        public int? ConfirmedById { get; set; }
        [ForeignKey(nameof(ConfirmedById))]
        public virtual User? ConfirmedBy { get; set; }

        public DateTime? CompletedAt { get; set; }
        public int? CompletedById { get; set; }
        [ForeignKey(nameof(CompletedById))]
        public virtual User? CompletedBy { get; set; }

        public DateTime? CancelledAt { get; set; }
        public int? CancelledById { get; set; }
        [ForeignKey(nameof(CancelledById))]
        public virtual User? CancelledBy { get; set; }

        [MaxLength(500)]
        public string? CancellationReason { get; set; }

        public DateTime? RescheduledAt { get; set; }
        public int? RescheduledById { get; set; }
        [ForeignKey(nameof(RescheduledById))]
        public virtual User? RescheduledBy { get; set; }

        [MaxLength(500)]
        public string? RescheduleReason { get; set; }

        public int? PayPalPaymentId { get; set; }
        [ForeignKey(nameof(PayPalPaymentId))]
        public virtual PayPalPayment? Payment { get; set; }

        public virtual MedicalRecordEntry? MedicalRecordEntry { get; set; }
        public virtual VideoCallSession? VideoCallSession { get; set; }
        public virtual Review? Review { get; set; }
    }
}
