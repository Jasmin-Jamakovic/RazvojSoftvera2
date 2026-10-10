using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class LabResultUpsertRequest
    {
        [Required] public int PatientId { get; set; }
        [Required, MaxLength(200)] public string Title { get; set; } = string.Empty;
        [MaxLength(2000)] public string? Notes { get; set; }
    }
}
