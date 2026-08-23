using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class ChangePasswordRequest
    {
        [Required] public string OldPassword { get; set; } = string.Empty;
        [Required, MinLength(6)] public string NewPassword { get; set; } = string.Empty;
    }
}
