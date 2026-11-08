using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace eDoktor.Services.Database.Entities
{
    /// <summary>
    /// Reference (lookup) entity for countries; every city belongs to one country.
    /// Managed via CRUD in the admin app.
    /// </summary>
    public class Country
    {
        public int Id { get; set; }

        [Required]
        [MaxLength(100)]
        public string Name { get; set; } = string.Empty;

        public bool IsDeleted { get; set; } = false;

        public virtual ICollection<City> Cities { get; set; } = new HashSet<City>();
    }
}
