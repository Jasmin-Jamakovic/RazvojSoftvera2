using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    // A user signs in with either their email address (patients in the mobile app) or their username
    // (staff in the desktop app). Exactly one of the two is expected; the service checks that one is present.
    public class LoginRequest
    {
        [MaxLength(100)]
        public string? Username { get; set; }

        [MaxLength(100)]
        public string? Email { get; set; }

        [Required]
        public string Password { get; set; } = string.Empty;
    }
}
