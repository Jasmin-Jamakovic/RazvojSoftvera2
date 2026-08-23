using System.Collections.Generic;

namespace eDoktor.Model.Responses
{
    public class MedicalRecordResponse
    {
        public int Id { get; set; }
        public int PatientId { get; set; }
        public string? PatientName { get; set; }
        public string? BloodType { get; set; }
        public string? Allergies { get; set; }
        public System.DateTime? DateOfBirth { get; set; }
        public List<MedicalRecordEntryResponse> Entries { get; set; } = new();
        public List<LabResultResponse> LabResults { get; set; } = new();
        public List<PrescriptionResponse> Prescriptions { get; set; } = new();
    }
}
