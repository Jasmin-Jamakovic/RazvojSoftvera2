using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class CityUpsertRequest
    {
        [Required, MaxLength(100)] public string Name { get; set; } = string.Empty;
        [MaxLength(100)] public string? Country { get; set; }
    }
}
