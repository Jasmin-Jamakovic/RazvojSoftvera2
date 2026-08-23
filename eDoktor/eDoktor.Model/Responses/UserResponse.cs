using System;

namespace eDoktor.Model.Responses
{
    public class UserResponse
    {
        public int Id { get; set; }
        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;
        public string Username { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string? PhoneNumber { get; set; }
        public DateTime? DateOfBirth { get; set; }
        public string? Gender { get; set; }
        public string? BloodType { get; set; }
        public string? Allergies { get; set; }
        public int? CityId { get; set; }
        public string? CityName { get; set; }
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public int RoleId { get; set; }
        public string? Role { get; set; }
        public bool ReceiveNotifications { get; set; }
        // Image bytes are only sent on detail/self endpoints. List endpoints send HasImage instead
        // and the client fetches it from GET /api/users/{id}/photo (spec §8.2: no blobs in lists).
        public byte[]? Image { get; set; }
        public bool HasImage { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
