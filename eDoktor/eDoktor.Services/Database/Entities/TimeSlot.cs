using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    public class TimeSlot
    {
        public int Id { get; set; }

        public int DoctorId { get; set; }
        [ForeignKey(nameof(DoctorId))]
        public virtual Doctor Doctor { get; set; } = null!;

        public DateTime StartUtc { get; set; }

        public DateTime EndUtc { get; set; }

        public bool IsBooked { get; set; } = false;

        // Concurrency token: two patients booking the same free slot at the same moment can't both win;
        // the second SaveChanges gets a DbUpdateConcurrencyException.
        [Timestamp]
        public byte[] RowVersion { get; set; } = default!;
    }
}
