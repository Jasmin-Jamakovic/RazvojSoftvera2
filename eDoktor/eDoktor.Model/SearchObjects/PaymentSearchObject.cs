using System;

namespace eDoktor.Model.SearchObjects
{
    public class PaymentSearchObject : BaseSearchObject
    {
        public string? Status { get; set; }
        public int? PatientId { get; set; }
        public int? DoctorId { get; set; }
        // Matches patient or doctor first/last name.
        public string? Search { get; set; }
        public DateTime? From { get; set; }
        public DateTime? To { get; set; }
    }
}
