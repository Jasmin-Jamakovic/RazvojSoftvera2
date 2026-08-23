namespace eDoktor.Model.SearchObjects
{
    public class DoctorSearchObject : BaseSearchObject
    {
        public string? Name { get; set; }
        public int? SpecializationId { get; set; }
        public int? ClinicId { get; set; }
        public double? MinRating { get; set; }
        public decimal? MaxPrice { get; set; }
        public bool? HasSlotInNext7Days { get; set; }
    }
}
