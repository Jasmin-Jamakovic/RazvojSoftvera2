using System;
using System.Collections.Generic;

namespace eDoktor.Model.Responses
{
    public class PrescriptionResponse
    {
        public int Id { get; set; }
        public int MedicalRecordEntryId { get; set; }
        public int AppointmentId { get; set; }
        public string? DoctorName { get; set; }
        public DateTime IssuedAt { get; set; }
        public List<PrescriptionItemResponse> Items { get; set; } = new();
    }

    public class PrescriptionItemResponse
    {
        public int Id { get; set; }
        public string Medication { get; set; } = string.Empty;
        public string? Dosage { get; set; }
        public string? Frequency { get; set; }
        public string? Duration { get; set; }
    }
}
