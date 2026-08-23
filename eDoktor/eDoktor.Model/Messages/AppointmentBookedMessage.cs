using System;

namespace eDoktor.Model.Messages
{
    public class AppointmentBookedMessage
    {
        public int AppointmentId { get; set; }
        public int PatientId { get; set; }
        public int DoctorId { get; set; }
        public string PatientEmail { get; set; } = string.Empty;
        public string PatientName { get; set; } = string.Empty;
        public string DoctorName { get; set; } = string.Empty;
        public DateTime StartUtc { get; set; }
        public string Type { get; set; } = "InPerson";
    }
}
