namespace eDoktor.Model.Responses
{
    public class PayPalOrderResponse
    {
        public string OrderId { get; set; } = string.Empty;
        public string? ApproveUrl { get; set; }
        public int AppointmentId { get; set; }
    }
}
