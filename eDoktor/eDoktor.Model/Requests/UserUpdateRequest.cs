using System;
using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    // Partial update: only the fields that are sent (non-null) are changed.
    public class UserUpdateRequest
    {
        [MinLength(1, ErrorMessage = "Ime ne smije biti prazno."), MaxLength(50, ErrorMessage = "Ime smije imati najviše 50 znakova.")]
        public string? FirstName { get; set; }

        [MinLength(1, ErrorMessage = "Prezime ne smije biti prazno."), MaxLength(50, ErrorMessage = "Prezime smije imati najviše 50 znakova.")]
        public string? LastName { get; set; }

        [EmailAddress(ErrorMessage = ValidationPatterns.EmailMessage), MaxLength(100)]
        public string? Email { get; set; }

        [RegularExpression(ValidationPatterns.Phone, ErrorMessage = ValidationPatterns.PhoneMessage)]
        public string? PhoneNumber { get; set; }

        public DateTime? DateOfBirth { get; set; }

        [RegularExpression(ValidationPatterns.Gender, ErrorMessage = ValidationPatterns.GenderMessage)]
        public string? Gender { get; set; }

        [RegularExpression(ValidationPatterns.BloodType, ErrorMessage = ValidationPatterns.BloodTypeMessage)]
        public string? BloodType { get; set; }

        [MaxLength(500, ErrorMessage = "Alergije smiju imati najviše 500 znakova.")]
        public string? Allergies { get; set; }

        public int? CityId { get; set; }

        [Range(-90, 90, ErrorMessage = "Geografska širina mora biti između -90 i 90.")]
        public double? Latitude { get; set; }

        [Range(-180, 180, ErrorMessage = "Geografska dužina mora biti između -180 i 180.")]
        public double? Longitude { get; set; }

        public bool? ReceiveNotifications { get; set; }
        public byte[]? Image { get; set; }
    }
}
