using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class TimeSlotGenerateRequest
    {
        [Range(1, int.MaxValue, ErrorMessage = "Odaberite ljekara.")]
        public int DoctorId { get; set; }

        [Range(10, 240, ErrorMessage = "Trajanje termina mora biti između 10 i 240 minuta.")]
        public int SlotMinutes { get; set; } = 30;

        // One working window per selected day. The client converts its local working hours to UTC,
        // so days on either side of a daylight-saving change get the correct UTC times.
        [Required(ErrorMessage = "Odaberite barem jedan radni dan.")]
        [MinLength(1, ErrorMessage = "Odaberite barem jedan radni dan.")]
        [MaxLength(93, ErrorMessage = "Radno vrijeme se može unijeti za najviše 93 dana odjednom.")]
        public List<WorkingWindow> Windows { get; set; } = new();
    }

    public class WorkingWindow
    {
        public DateTime StartUtc { get; set; }
        public DateTime EndUtc { get; set; }
    }
}
