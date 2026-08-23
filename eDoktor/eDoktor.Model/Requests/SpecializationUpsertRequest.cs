using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class SpecializationUpsertRequest
    {
        [Required, MaxLength(100)] public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
    }
}
