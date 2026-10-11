using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class DoctorUpsertRequest
    {
        // On insert: full user info to create the linked doctor account (email is required then, the
        // temporary password is sent there). On update: username and email are not changed.
        [Required(ErrorMessage = "Ime je obavezno."), MaxLength(50)] public string FirstName { get; set; } = string.Empty;
        [Required(ErrorMessage = "Prezime je obavezno."), MaxLength(50)] public string LastName { get; set; } = string.Empty;

        [MaxLength(50), RegularExpression(@"^[a-zA-Z0-9._-]{3,50}$", ErrorMessage = "Korisničko ime smije sadržavati slova, brojeve i . _ - (3–50 znakova).")]
        public string? Username { get; set; }

        [EmailAddress(ErrorMessage = ValidationPatterns.EmailMessage), MaxLength(100)]
        public string? Email { get; set; }

        [RegularExpression(ValidationPatterns.Phone, ErrorMessage = ValidationPatterns.PhoneMessage)]
        public string? PhoneNumber { get; set; }

        [Range(1, int.MaxValue, ErrorMessage = "Odaberite kliniku.")] public int ClinicId { get; set; }

        [MaxLength(1000, ErrorMessage = "Biografija smije imati najviše 1000 znakova.")] public string? Bio { get; set; }

        [Range(0, 70, ErrorMessage = "Godine iskustva moraju biti između 0 i 70.")] public int YearsExperience { get; set; }

        [Range(typeof(decimal), "1", "10000", ErrorMessage = "Cijena konsultacije mora biti između 1 i 10000 EUR.")]
        public decimal ConsultationPrice { get; set; }

        public byte[]? ProfilePhoto { get; set; }

        [MinLength(1, ErrorMessage = "Odaberite barem jednu specijalizaciju.")]
        public List<int> SpecializationIds { get; set; } = new();
    }
}
