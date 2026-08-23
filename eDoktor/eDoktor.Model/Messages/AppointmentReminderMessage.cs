using System;

namespace eDoktor.Model.Messages
{
    public class AppointmentReminderMessage
    {
        public int AppointmentId { get; set; }
        public int PatientId { get; set; }
        public string PatientEmail { get; set; } = string.Empty;
        public string PatientName { get; set; } = string.Empty;
        public string DoctorName { get; set; } = string.Empty;
        public DateTime StartUtc { get; set; }
        // 24h or 1h
        public string Window { get; set; } = "24h";
    }
}
