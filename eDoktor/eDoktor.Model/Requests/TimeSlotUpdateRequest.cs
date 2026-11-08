using System;
using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    /// Moves one free slot to a different time.
    public class TimeSlotUpdateRequest
    {
        [Required] public DateTime StartUtc { get; set; }
        [Required] public DateTime EndUtc { get; set; }
    }
}
