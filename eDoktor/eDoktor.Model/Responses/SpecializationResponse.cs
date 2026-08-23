namespace eDoktor.Model.Responses
{
    public class SpecializationResponse
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public bool IsDeleted { get; set; }
    }
}
