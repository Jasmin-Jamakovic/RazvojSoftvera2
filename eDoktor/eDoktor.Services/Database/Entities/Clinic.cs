using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    public class Clinic
    {
        public int Id { get; set; }

        [Required]
        [MaxLength(150)]
        public string Name { get; set; } = string.Empty;

        [MaxLength(200)]
        public string? Address { get; set; }

        public int? CityId { get; set; }
        [ForeignKey(nameof(CityId))]
        public virtual City? City { get; set; }

        public double? Latitude { get; set; }

        public double? Longitude { get; set; }

        public bool IsDeleted { get; set; } = false;

        public virtual ICollection<Doctor> Doctors { get; set; } = new HashSet<Doctor>();
    }
}
