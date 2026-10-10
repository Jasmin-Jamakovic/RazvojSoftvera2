using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class AppointmentRescheduleRequest
    {
        [Range(1, int.MaxValue, ErrorMessage = "Odaberite novi termin.")]
        public int NewTimeSlotId { get; set; }

        [Required(ErrorMessage = "Razlog pomjeranja je obavezan.")]
        [StringLength(500, MinimumLength = 3, ErrorMessage = "Razlog pomjeranja mora imati između 3 i 500 znakova.")]
        public string Reason { get; set; } = string.Empty;
    }
}
