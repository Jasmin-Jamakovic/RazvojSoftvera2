using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class ReviewUpsertRequest
    {
        [Required] public int AppointmentId { get; set; }
        [Range(1, 5)] public int Rating { get; set; }
        public string? Comment { get; set; }
    }
}
