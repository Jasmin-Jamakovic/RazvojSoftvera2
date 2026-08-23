using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    public class VideoCallSession
    {
        public int Id { get; set; }

        public int AppointmentId { get; set; }
        [ForeignKey(nameof(AppointmentId))]
        public virtual Appointment Appointment { get; set; } = null!;

        [Required]
        [MaxLength(200)]
        public string RoomId { get; set; } = string.Empty;

        public DateTime? StartedAt { get; set; }

        public DateTime? EndedAt { get; set; }
    }
}
