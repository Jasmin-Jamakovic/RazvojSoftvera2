namespace eDoktor.Model.Responses
{
    /// The record "header". Visits, prescriptions and lab results are fetched page by page from their own endpoints.
    public class MedicalRecordResponse
    {
        public int Id { get; set; }
        public int PatientId { get; set; }
        public string? PatientName { get; set; }
        public string? BloodType { get; set; }
        public string? Allergies { get; set; }
        public System.DateTime? DateOfBirth { get; set; }
        public int EntryCount { get; set; }
        public int PrescriptionCount { get; set; }
        public int LabResultCount { get; set; }
    }
}
