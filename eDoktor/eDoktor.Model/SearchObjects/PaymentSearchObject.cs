namespace eDoktor.Model.SearchObjects
{
    public class PaymentSearchObject : BaseSearchObject
    {
        public string? Status { get; set; }
        public int? PatientId { get; set; }
    }
}
