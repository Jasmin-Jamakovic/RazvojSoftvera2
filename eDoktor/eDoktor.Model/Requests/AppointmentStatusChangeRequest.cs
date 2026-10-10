using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class AppointmentStatusChangeRequest
    {
        // Required when a doctor or admin cancels (the patient is told why); optional for the patient.
        [MaxLength(500, ErrorMessage = "Razlog smije imati najviše 500 znakova.")]
        public string? Reason { get; set; }
    }
}
