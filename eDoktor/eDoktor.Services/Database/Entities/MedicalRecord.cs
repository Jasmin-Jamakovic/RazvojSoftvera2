using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    public class MedicalRecord
    {
        public int Id { get; set; }

        public int PatientId { get; set; }
        [ForeignKey(nameof(PatientId))]
        public virtual User Patient { get; set; } = null!;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public virtual ICollection<MedicalRecordEntry> Entries { get; set; } = new HashSet<MedicalRecordEntry>();
        public virtual ICollection<LabResult> LabResults { get; set; } = new HashSet<LabResult>();
    }
}
