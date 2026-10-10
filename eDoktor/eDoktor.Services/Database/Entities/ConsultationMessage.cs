using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    // Chat message (text and/or shared photo, e.g. of a finding) exchanged during an online consultation.
    public class ConsultationMessage
    {
        public int Id { get; set; }

        public int AppointmentId { get; set; }
        [ForeignKey(nameof(AppointmentId))]
        public virtual Appointment Appointment { get; set; } = null!;

        public int SenderId { get; set; }
        [ForeignKey(nameof(SenderId))]
        public virtual User Sender { get; set; } = null!;

        [MaxLength(2000)]
        public string? Text { get; set; }

        public byte[]? Image { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
