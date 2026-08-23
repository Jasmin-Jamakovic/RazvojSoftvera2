using System;

namespace eDoktor.Model.Responses
{
    public class ReviewResponse
    {
        public int Id { get; set; }
        public int AppointmentId { get; set; }
        public int DoctorId { get; set; }
        public int PatientId { get; set; }
        public string? PatientName { get; set; }
        public int Rating { get; set; }
        public string? Comment { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
