namespace eDoktor.Model.Responses
{
    public class CityResponse
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Country { get; set; }
        public bool IsDeleted { get; set; }
    }
}
