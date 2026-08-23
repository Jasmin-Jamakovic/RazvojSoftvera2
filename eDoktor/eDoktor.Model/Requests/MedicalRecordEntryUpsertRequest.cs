using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class MedicalRecordEntryUpsertRequest
    {
        [Required] public int AppointmentId { get; set; }
        public string? Diagnosis { get; set; }
        public string? Therapy { get; set; }
        public string? Notes { get; set; }
    }
}
