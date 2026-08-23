using System;

namespace eDoktor.Model.Responses
{
    public class TimeSlotResponse
    {
        public int Id { get; set; }
        public int DoctorId { get; set; }
        public DateTime StartUtc { get; set; }
        public DateTime EndUtc { get; set; }
        public bool IsBooked { get; set; }
    }
}
