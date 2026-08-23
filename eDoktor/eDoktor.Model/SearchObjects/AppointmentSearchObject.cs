using System;

namespace eDoktor.Model.SearchObjects
{
    public class AppointmentSearchObject : BaseSearchObject
    {
        public int? PatientId { get; set; }
        public int? DoctorId { get; set; }
        public string? Status { get; set; }
        public DateTime? From { get; set; }
        public DateTime? To { get; set; }
    }
}
