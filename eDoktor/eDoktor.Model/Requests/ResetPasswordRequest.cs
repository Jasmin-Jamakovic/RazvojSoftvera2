using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class ResetPasswordRequest
    {
        [Required(ErrorMessage = "Email je obavezan.")]
        [EmailAddress(ErrorMessage = "Unesite ispravnu email adresu (npr. ime@domena.com).")]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Kod je obavezan.")]
        [RegularExpression(@"^\d{6}$", ErrorMessage = "Kod mora imati tačno 6 cifara.")]
        public string Code { get; set; } = string.Empty;

        [Required(ErrorMessage = "Nova lozinka je obavezna.")]
        [MinLength(6, ErrorMessage = "Lozinka mora imati najmanje 6 znakova.")]
        public string NewPassword { get; set; } = string.Empty;
    }
}
