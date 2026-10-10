using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    // One-time password reset code sent by email. Only a BCrypt hash of the code is stored.
    public class PasswordResetCode
    {
        public int Id { get; set; }

        public int UserId { get; set; }
        [ForeignKey(nameof(UserId))]
        public virtual User User { get; set; } = null!;

        [Required]
        [MaxLength(100)]
        public string CodeHash { get; set; } = string.Empty;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime ExpiresAt { get; set; }

        // Failed verification attempts; the code is invalidated after too many.
        public int FailedAttempts { get; set; }

        public DateTime? UsedAt { get; set; }
    }
}
