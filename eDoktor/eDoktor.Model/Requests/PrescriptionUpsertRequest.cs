using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class PrescriptionUpsertRequest
    {
        /// Used on create only; an existing prescription stays on its visit.
        [Required] public int MedicalRecordEntryId { get; set; }
        [MinLength(1, ErrorMessage = "Recept mora imati barem jedan lijek.")]
        public List<PrescriptionItemRequest> Items { get; set; } = new();
    }

    public class PrescriptionItemRequest
    {
        [Required, MaxLength(200)] public string Medication { get; set; } = string.Empty;
        [MaxLength(100)] public string? Dosage { get; set; }
        [MaxLength(100)] public string? Frequency { get; set; }
        [MaxLength(100)] public string? Duration { get; set; }
    }
}
