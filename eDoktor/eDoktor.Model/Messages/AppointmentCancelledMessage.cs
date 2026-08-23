using System;

namespace eDoktor.Model.Messages
{
    public class AppointmentCancelledMessage
    {
        public int AppointmentId { get; set; }
        public int PatientId { get; set; }
        public int DoctorId { get; set; }
        public string PatientEmail { get; set; } = string.Empty;
        public string PatientName { get; set; } = string.Empty;
        public string DoctorName { get; set; } = string.Empty;
        public DateTime StartUtc { get; set; }
        public string? Reason { get; set; }
        public bool ShouldRefund { get; set; }
    }
}
