namespace eDoktor.Model.Responses
{
    // Totals for a period: gross by capture date, refunds by refund date, net = gross - refunds.
    public class PaymentSummaryResponse
    {
        // The period the totals cover (null = unbounded on that side).
        public System.DateTime? From { get; set; }
        public System.DateTime? To { get; set; }
        public decimal TotalCaptured { get; set; }
        public decimal TotalRefunded { get; set; }
        public decimal NetRevenue { get; set; }
        public int CapturedCount { get; set; }
        public int RefundedCount { get; set; }
        public int PendingCount { get; set; }
    }
}
