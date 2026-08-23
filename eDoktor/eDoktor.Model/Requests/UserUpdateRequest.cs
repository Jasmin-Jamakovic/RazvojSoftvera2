using System;

namespace eDoktor.Model.Requests
{
    public class UserUpdateRequest
    {
        public string? FirstName { get; set; }
        public string? LastName { get; set; }
        public string? Email { get; set; }
        public string? PhoneNumber { get; set; }
        public DateTime? DateOfBirth { get; set; }
        public string? Gender { get; set; }
        public string? BloodType { get; set; }
        public string? Allergies { get; set; }
        public int? CityId { get; set; }
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public bool? ReceiveNotifications { get; set; }
        public byte[]? Image { get; set; }
    }
}
