using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    /// <summary>
    /// Reference (lookup) entity for cities used in addresses (users, clinics).
    /// Managed via CRUD in the admin app.
    /// </summary>
    public class City
    {
        public int Id { get; set; }

        [Required]
        [MaxLength(100)]
        public string Name { get; set; } = string.Empty;

        public int CountryId { get; set; }
        [ForeignKey(nameof(CountryId))]
        public virtual Country Country { get; set; } = null!;

        public bool IsDeleted { get; set; } = false;
    }
}
