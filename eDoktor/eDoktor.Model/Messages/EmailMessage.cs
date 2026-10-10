namespace eDoktor.Model.Messages
{
    public enum EmailKind
    {
        Welcome = 0,
        DoctorCredentials = 1,
        AppointmentBooked = 2,
        AppointmentReminder = 3,
        AppointmentCancelled = 4,
        PaymentReceipt = 5,
        PrescriptionIssued = 6,
        AppointmentRescheduled = 7,
        PasswordReset = 8
    }

    public class EmailMessage
    {
        public string To { get; set; } = string.Empty;
        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;
        public string Subject { get; set; } = string.Empty;
        public string Body { get; set; } = string.Empty;
        public EmailKind Kind { get; set; } = EmailKind.Welcome;
    }
}
