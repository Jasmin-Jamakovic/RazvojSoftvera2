using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class LabResultUpsertRequest
    {
        [Required] public int PatientId { get; set; }
        [Required, MaxLength(200)] public string Title { get; set; } = string.Empty;
        public string? Notes { get; set; }
        public string? FileUrl { get; set; }
    }
}
