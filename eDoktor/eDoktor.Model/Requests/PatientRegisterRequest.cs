using System;
using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class PatientRegisterRequest
    {
        [Required(ErrorMessage = "Ime je obavezno."), MaxLength(50)] public string FirstName { get; set; } = string.Empty;
        [Required(ErrorMessage = "Prezime je obavezno."), MaxLength(50)] public string LastName { get; set; } = string.Empty;
        [Required(ErrorMessage = "Korisničko ime je obavezno."), MaxLength(50)] public string Username { get; set; } = string.Empty;
        [Required(ErrorMessage = "Email je obavezan."), EmailAddress(ErrorMessage = ValidationPatterns.EmailMessage), MaxLength(100)] public string Email { get; set; } = string.Empty;
        [Required(ErrorMessage = "Lozinka je obavezna."), MinLength(6, ErrorMessage = "Lozinka mora imati najmanje 6 znakova."), MaxLength(100)] public string Password { get; set; } = string.Empty;
        [RegularExpression(ValidationPatterns.Phone, ErrorMessage = ValidationPatterns.PhoneMessage)]
        public string? PhoneNumber { get; set; }
        [Required(ErrorMessage = "Datum rođenja je obavezan.")]
        public DateTime? DateOfBirth { get; set; }
        [RegularExpression(ValidationPatterns.Gender, ErrorMessage = ValidationPatterns.GenderMessage)]
        public string? Gender { get; set; }
        [RegularExpression(ValidationPatterns.BloodType, ErrorMessage = ValidationPatterns.BloodTypeMessage)]
        public string? BloodType { get; set; }
        [MaxLength(500)]
        public string? Allergies { get; set; }
        public int? CityId { get; set; }
        [Range(-90, 90)] public double? Latitude { get; set; }
        [Range(-180, 180)] public double? Longitude { get; set; }
    }
}
