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
        /// Oldest first (e.g. upcoming appointments, nearest first). Default: newest first.
        public bool SortAscending { get; set; }

        // "upcoming" = active (pending/confirmed) and not yet over; "past" = everything else
        // (finished, cancelled, or already over). Applied before paging, so every page belongs to the tab.
        public string? Period { get; set; }

        // Part of the patient's first/last name; applied before paging, so the total counts only matches.
        public string? PatientName { get; set; }
    }
}
