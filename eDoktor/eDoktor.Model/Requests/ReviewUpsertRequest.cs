using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class ReviewUpsertRequest
    {
        [Required] public int AppointmentId { get; set; }
        [Range(1, 5, ErrorMessage = "Ocjena mora biti između 1 i 5.")] public int Rating { get; set; }
        [MaxLength(1000, ErrorMessage = "Komentar smije imati najviše 1000 znakova.")] public string? Comment { get; set; }
    }
}
