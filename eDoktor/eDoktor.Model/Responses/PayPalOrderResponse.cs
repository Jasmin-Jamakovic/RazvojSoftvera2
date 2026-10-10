namespace eDoktor.Model.Responses
{
    public class PayPalOrderResponse
    {
        public string OrderId { get; set; } = string.Empty;
        public string? ApproveUrl { get; set; }
        public int AppointmentId { get; set; }
        // The client watches for these URLs to know the payer approved (then calls capture) or cancelled.
        public string ReturnUrl { get; set; } = string.Empty;
        public string CancelUrl { get; set; } = string.Empty;
    }
}
