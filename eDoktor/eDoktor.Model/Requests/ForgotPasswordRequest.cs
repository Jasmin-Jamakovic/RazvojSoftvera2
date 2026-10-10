using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class ForgotPasswordRequest
    {
        [Required(ErrorMessage = "Email je obavezan.")]
        [EmailAddress(ErrorMessage = "Unesite ispravnu email adresu (npr. ime@domena.com).")]
        public string Email { get; set; } = string.Empty;
    }
}
