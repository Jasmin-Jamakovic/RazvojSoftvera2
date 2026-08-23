using System;
using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class TimeSlotGenerateRequest
    {
        [Required] public int DoctorId { get; set; }
        [Required] public DateTime From { get; set; }
        [Required] public DateTime To { get; set; }
        public int StartHour { get; set; } = 9;
        public int EndHour { get; set; } = 17;
        public int SlotMinutes { get; set; } = 30;
    }
}
