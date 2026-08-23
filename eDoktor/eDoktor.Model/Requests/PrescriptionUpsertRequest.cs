using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class PrescriptionUpsertRequest
    {
        [Required] public int MedicalRecordEntryId { get; set; }
        public List<PrescriptionItemRequest> Items { get; set; } = new();
    }

    public class PrescriptionItemRequest
    {
        [Required, MaxLength(200)] public string Medication { get; set; } = string.Empty;
        public string? Dosage { get; set; }
        public string? Frequency { get; set; }
        public string? Duration { get; set; }
    }
}
