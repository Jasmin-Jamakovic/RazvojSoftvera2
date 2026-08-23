using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    public class Review
    {
        public int Id { get; set; }

        public int AppointmentId { get; set; }
        [ForeignKey(nameof(AppointmentId))]
        public virtual Appointment Appointment { get; set; } = null!;

        public int DoctorId { get; set; }
        [ForeignKey(nameof(DoctorId))]
        public virtual Doctor Doctor { get; set; } = null!;

        public int PatientId { get; set; }
        [ForeignKey(nameof(PatientId))]
        public virtual User Patient { get; set; } = null!;

        [Range(1, 5)]
        public int Rating { get; set; }

        [MaxLength(2000)]
        public string? Comment { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public bool IsDeleted { get; set; } = false;
    }
}
