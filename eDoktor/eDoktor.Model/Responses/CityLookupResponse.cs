namespace eDoktor.Model.Responses
{
    /// Minimal city data (id + name) for pickers that are open before login, e.g. patient registration.
    public class CityLookupResponse
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
    }
}
