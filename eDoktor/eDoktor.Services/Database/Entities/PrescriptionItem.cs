using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    public class PrescriptionItem
    {
        public int Id { get; set; }

        public int PrescriptionId { get; set; }
        [ForeignKey(nameof(PrescriptionId))]
        public virtual Prescription Prescription { get; set; } = null!;

        [Required]
        [MaxLength(200)]
        public string Medication { get; set; } = string.Empty;

        [MaxLength(100)]
        public string? Dosage { get; set; }

        [MaxLength(100)]
        public string? Frequency { get; set; }

        [MaxLength(100)]
        public string? Duration { get; set; }
    }
}
