using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class MedicalRecordEntryUpsertRequest
    {
        /// Used on create only; an existing entry stays on its appointment.
        [Required] public int AppointmentId { get; set; }
        [Required(ErrorMessage = "Unesite dijagnozu."), MaxLength(2000)] public string? Diagnosis { get; set; }
        [MaxLength(4000)] public string? Therapy { get; set; }
        [MaxLength(4000)] public string? Notes { get; set; }
    }
}
