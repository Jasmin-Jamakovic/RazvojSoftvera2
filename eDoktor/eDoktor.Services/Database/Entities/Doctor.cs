using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    public class Doctor
    {
        public int Id { get; set; }

        public int UserId { get; set; }
        [ForeignKey(nameof(UserId))]
        public virtual User User { get; set; } = null!;

        public int ClinicId { get; set; }
        [ForeignKey(nameof(ClinicId))]
        public virtual Clinic Clinic { get; set; } = null!;

        [MaxLength(2000)]
        public string? Bio { get; set; }

        public int YearsExperience { get; set; }

        [Column(TypeName = "decimal(10,2)")]
        public decimal ConsultationPrice { get; set; }

        public byte[]? ProfilePhoto { get; set; }

        public bool IsDeleted { get; set; } = false;

        public virtual ICollection<DoctorSpecialization> DoctorSpecializations { get; set; } = new HashSet<DoctorSpecialization>();
        public virtual ICollection<TimeSlot> TimeSlots { get; set; } = new HashSet<TimeSlot>();
        public virtual ICollection<Appointment> Appointments { get; set; } = new HashSet<Appointment>();
        public virtual ICollection<Review> Reviews { get; set; } = new HashSet<Review>();
    }
}
