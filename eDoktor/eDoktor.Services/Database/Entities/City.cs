using System.ComponentModel.DataAnnotations;

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

        [MaxLength(100)]
        public string? Country { get; set; }

        public bool IsDeleted { get; set; } = false;
    }
}
