namespace eDoktor.Model.Responses
{
    public class ClinicResponse
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Address { get; set; }
        public int? CityId { get; set; }
        public string? CityName { get; set; }
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public bool IsDeleted { get; set; }
    }
}
