using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace eDoktor.Services.Database.Entities
{
    public class Specialization
    {
        public int Id { get; set; }

        [Required]
        [MaxLength(100)]
        public string Name { get; set; } = string.Empty;

        [MaxLength(500)]
        public string? Description { get; set; }

        public bool IsDeleted { get; set; } = false;

        public virtual ICollection<DoctorSpecialization> DoctorSpecializations { get; set; } = new HashSet<DoctorSpecialization>();
    }
}
