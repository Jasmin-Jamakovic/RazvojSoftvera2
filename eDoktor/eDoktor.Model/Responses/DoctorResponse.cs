using System.Collections.Generic;

namespace eDoktor.Model.Responses
{
    public class DoctorResponse
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;
        public string FullName => $"{FirstName} {LastName}".Trim();
        public string? Bio { get; set; }
        public int YearsExperience { get; set; }
        public decimal ConsultationPrice { get; set; }
        // Photo bytes are only sent on the detail endpoint. List endpoints send HasPhoto instead
        // and the client fetches the image from GET /api/doctors/{id}/photo (spec §8.2: no blobs in lists).
        public byte[]? ProfilePhoto { get; set; }
        public bool HasPhoto { get; set; }
        public ClinicResponse? Clinic { get; set; }
        public List<SpecializationResponse> Specializations { get; set; } = new();
        public double AverageRating { get; set; }
        public int ReviewCount { get; set; }
        public bool IsDeleted { get; set; }

        // Used when produced by the recommender.
        public string? RecommendationReason { get; set; }
    }
}
