using System;

namespace eDoktor.Model.Responses
{
    public class LabResultResponse
    {
        public int Id { get; set; }
        public int MedicalRecordId { get; set; }
        public string Title { get; set; } = string.Empty;
        public string? Notes { get; set; }
        public string? FileUrl { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
