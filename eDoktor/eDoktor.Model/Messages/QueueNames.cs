namespace eDoktor.Model.Messages
{
    public static class QueueNames
    {
        public const string Email = "email";
        public const string AppointmentBooked = "appointment.booked";
        public const string AppointmentCancelled = "appointment.cancelled";
        public const string AppointmentReminder = "appointment.reminder";
        public const string PaymentCaptured = "payment.captured";
        public const string PrescriptionIssued = "prescription.issued";
        public const string DoctorCreated = "doctor.created";
    }
}
