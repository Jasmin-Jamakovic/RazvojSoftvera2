using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class LabResultUpsertRequest
    {
        /// Used on create only; an existing result stays in its patient's record.
        [Required] public int PatientId { get; set; }
        [Required, MaxLength(200)] public string Title { get; set; } = string.Empty;
        [MaxLength(2000)] public string? Notes { get; set; }
    }
}
