using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class PayPalCreateOrderRequest
    {
        [Required] public int AppointmentId { get; set; }
    }
}
