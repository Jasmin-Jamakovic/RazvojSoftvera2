using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eDoktor.Services.Database.Entities
{
    // A patient's doctor search (name text and/or specialization filter). Feeds the recommender's patient profile.
    public class SearchHistory
    {
        public int Id { get; set; }

        public int UserId { get; set; }
        [ForeignKey(nameof(UserId))]
        public virtual User User { get; set; } = null!;

        [MaxLength(100)]
        public string? Query { get; set; }

        public int? SpecializationId { get; set; }
        [ForeignKey(nameof(SpecializationId))]
        public virtual Specialization? Specialization { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
