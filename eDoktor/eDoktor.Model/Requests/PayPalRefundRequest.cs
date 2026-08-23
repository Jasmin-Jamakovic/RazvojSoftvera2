namespace eDoktor.Model.Requests
{
    public class PayPalRefundRequest
    {
        public decimal? Amount { get; set; }
        public string? Reason { get; set; }
    }
}
