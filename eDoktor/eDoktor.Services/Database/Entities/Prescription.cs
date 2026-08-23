using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    public class Prescription
    {
        public int Id { get; set; }

        public int MedicalRecordEntryId { get; set; }
        [ForeignKey(nameof(MedicalRecordEntryId))]
        public virtual MedicalRecordEntry MedicalRecordEntry { get; set; } = null!;

        public DateTime IssuedAt { get; set; } = DateTime.UtcNow;

        public virtual ICollection<PrescriptionItem> Items { get; set; } = new HashSet<PrescriptionItem>();
    }
}
