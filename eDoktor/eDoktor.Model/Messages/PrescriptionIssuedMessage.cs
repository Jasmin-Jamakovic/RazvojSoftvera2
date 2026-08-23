namespace eDoktor.Model.Messages
{
    public class PrescriptionIssuedMessage
    {
        public int PrescriptionId { get; set; }
        public int AppointmentId { get; set; }
        public int PatientId { get; set; }
        public string PatientEmail { get; set; } = string.Empty;
        public string PatientName { get; set; } = string.Empty;
        public string DoctorName { get; set; } = string.Empty;
    }
}
