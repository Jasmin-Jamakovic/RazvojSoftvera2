using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    public class DoctorSpecialization
    {
        public int DoctorId { get; set; }
        [ForeignKey(nameof(DoctorId))]
        public virtual Doctor Doctor { get; set; } = null!;

        public int SpecializationId { get; set; }
        [ForeignKey(nameof(SpecializationId))]
        public virtual Specialization Specialization { get; set; } = null!;
    }
}
