using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    public class MedicalRecordEntry
    {
        public int Id { get; set; }

        public int MedicalRecordId { get; set; }
        [ForeignKey(nameof(MedicalRecordId))]
        public virtual MedicalRecord MedicalRecord { get; set; } = null!;

        public int AppointmentId { get; set; }
        [ForeignKey(nameof(AppointmentId))]
        public virtual Appointment Appointment { get; set; } = null!;

        [MaxLength(2000)]
        public string? Diagnosis { get; set; }

        [MaxLength(4000)]
        public string? Therapy { get; set; }

        [MaxLength(4000)]
        public string? Notes { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public virtual Prescription? Prescription { get; set; }
    }
}
