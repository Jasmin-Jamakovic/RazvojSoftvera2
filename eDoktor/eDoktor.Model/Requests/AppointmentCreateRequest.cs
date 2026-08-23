using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class AppointmentCreateRequest
    {
        [Required] public int DoctorId { get; set; }
        [Required] public int TimeSlotId { get; set; }
        // 0 = InPerson, 1 = Online
        public int Type { get; set; } = 0;
    }
}
