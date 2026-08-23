using System;

namespace eDoktor.Model.SearchObjects
{
    public class TimeSlotSearchObject : BaseSearchObject
    {
        public int? DoctorId { get; set; }
        public DateTime? From { get; set; }
        public DateTime? To { get; set; }
        public bool? OnlyAvailable { get; set; }
    }
}
