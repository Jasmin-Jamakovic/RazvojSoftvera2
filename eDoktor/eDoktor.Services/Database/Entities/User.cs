using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    public class User
    {
        public int Id { get; set; }

        [Required]
        [MaxLength(50)]
        public string FirstName { get; set; } = string.Empty;

        [Required]
        [MaxLength(50)]
        public string LastName { get; set; } = string.Empty;

        [Required]
        [MaxLength(50)]
        public string Username { get; set; } = string.Empty;

        [Required]
        [EmailAddress]
        [MaxLength(100)]
        public string Email { get; set; } = string.Empty;

        [Required]
        public string PasswordHash { get; set; } = string.Empty;

        [Phone]
        public string? PhoneNumber { get; set; }

        public DateTime? DateOfBirth { get; set; }

        [MaxLength(20)]
        public string? Gender { get; set; }

        [MaxLength(10)]
        public string? BloodType { get; set; }

        [MaxLength(1000)]
        public string? Allergies { get; set; }

        public int? CityId { get; set; }
        [ForeignKey(nameof(CityId))]
        public virtual City? City { get; set; }

        public double? Latitude { get; set; }

        public double? Longitude { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime? LastModifiedAt { get; set; }

        public bool ReceiveNotifications { get; set; } = true;

        public bool IsDeleted { get; set; } = false;

        // Bumped on logout / password change to invalidate previously issued JWTs server-side.
        public int TokenVersion { get; set; } = 0;

        public byte[]? Image { get; set; }

        public int RoleId { get; set; }
        [ForeignKey(nameof(RoleId))]
        public virtual Role Role { get; set; } = null!;

        public virtual Doctor? DoctorProfile { get; set; }
        public virtual MedicalRecord? MedicalRecord { get; set; }
        public virtual ICollection<Appointment> AppointmentsAsPatient { get; set; } = new HashSet<Appointment>();
        public virtual ICollection<Review> ReviewsWritten { get; set; } = new HashSet<Review>();
        public virtual ICollection<Notification> Notifications { get; set; } = new HashSet<Notification>();
    }
}
