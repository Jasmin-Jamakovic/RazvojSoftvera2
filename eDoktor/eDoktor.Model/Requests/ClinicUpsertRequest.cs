using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class ClinicUpsertRequest
    {
        [Required(ErrorMessage = "Naziv je obavezan."), MaxLength(150)] public string Name { get; set; } = string.Empty;
        [Required(ErrorMessage = "Adresa je obavezna."), MaxLength(200)] public string? Address { get; set; }
        [Required(ErrorMessage = "Odaberite grad.")] public int? CityId { get; set; }

        // Picked on a map or looked up from the address. Left out (null) on update = keep the stored value.
        [Range(-90, 90, ErrorMessage = "Geografska širina mora biti između -90 i 90.")] public double? Latitude { get; set; }
        [Range(-180, 180, ErrorMessage = "Geografska dužina mora biti između -180 i 180.")] public double? Longitude { get; set; }
    }
}
