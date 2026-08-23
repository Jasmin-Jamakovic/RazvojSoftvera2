using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class ClinicUpsertRequest
    {
        [Required, MaxLength(150)] public string Name { get; set; } = string.Empty;
        public string? Address { get; set; }
        public int? CityId { get; set; }
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
    }
}
