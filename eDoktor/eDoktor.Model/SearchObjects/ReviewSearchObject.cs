namespace eDoktor.Model.SearchObjects
{
    public class ReviewSearchObject : BaseSearchObject
    {
        public int? DoctorId { get; set; }
        public int? PatientId { get; set; }
    }
}
