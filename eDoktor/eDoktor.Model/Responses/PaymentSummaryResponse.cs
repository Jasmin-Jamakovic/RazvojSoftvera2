namespace eDoktor.Model.Responses
{
    public class PaymentSummaryResponse
    {
        public decimal TotalCaptured { get; set; }
        public decimal TotalRefunded { get; set; }
        public decimal NetRevenue { get; set; }
        public int CapturedCount { get; set; }
        public int RefundedCount { get; set; }
        public int PendingCount { get; set; }
    }
}
