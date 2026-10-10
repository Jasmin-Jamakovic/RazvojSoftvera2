using System;
using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class PatientRegisterRequest
    {
        [Required, MaxLength(50)] public string FirstName { get; set; } = string.Empty;
        [Required, MaxLength(50)] public string LastName { get; set; } = string.Empty;
        [Required, MaxLength(50)] public string Username { get; set; } = string.Empty;
        [Required, EmailAddress, MaxLength(100)] public string Email { get; set; } = string.Empty;
        [Required, MinLength(6)] public string Password { get; set; } = string.Empty;
        public string? PhoneNumber { get; set; }
        [Required(ErrorMessage = "Datum rođenja je obavezan.")]
        public DateTime? DateOfBirth { get; set; }
        public string? Gender { get; set; }
        public string? BloodType { get; set; }
        public string? Allergies { get; set; }
        public int? CityId { get; set; }
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
    }
}
