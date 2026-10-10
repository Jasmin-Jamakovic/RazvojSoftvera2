using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    public class LabResult
    {
        public int Id { get; set; }

        public int MedicalRecordId { get; set; }
        [ForeignKey(nameof(MedicalRecordId))]
        public virtual MedicalRecord MedicalRecord { get; set; } = null!;

        [Required]
        [MaxLength(200)]
        public string Title { get; set; } = string.Empty;

        [MaxLength(4000)]
        public string? Notes { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
