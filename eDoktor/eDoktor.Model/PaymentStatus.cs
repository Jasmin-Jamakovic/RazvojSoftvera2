namespace eDoktor.Model
{
    // PayPal payment lifecycle states, centralized instead of scattered magic strings (spec §3.4).
    public static class PaymentStatus
    {
        public const string Created = "Created";
        public const string Captured = "Captured";
        public const string Refunded = "Refunded";
        // An unfinished order replaced by a newer one (the patient abandoned the PayPal page and retried).
        public const string Cancelled = "Cancelled";
    }
}
