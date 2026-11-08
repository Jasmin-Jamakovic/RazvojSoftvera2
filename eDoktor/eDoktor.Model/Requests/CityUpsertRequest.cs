using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class CityUpsertRequest
    {
        [Required, MaxLength(100)] public string Name { get; set; } = string.Empty;
        [Required, Range(1, int.MaxValue, ErrorMessage = "Odaberite državu.")] public int CountryId { get; set; }
    }
}
