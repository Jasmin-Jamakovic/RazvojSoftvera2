namespace eDoktor.Model.Messages
{
    public class PaymentCapturedMessage
    {
        public int PaymentId { get; set; }
        public int AppointmentId { get; set; }
        public int PatientId { get; set; }
        public string PatientEmail { get; set; } = string.Empty;
        public string PatientName { get; set; } = string.Empty;
        public decimal Amount { get; set; }
        public string Currency { get; set; } = "EUR";
    }
}
