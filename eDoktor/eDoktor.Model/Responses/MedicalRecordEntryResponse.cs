using System;

namespace eDoktor.Model.Responses
{
    public class MedicalRecordEntryResponse
    {
        public int Id { get; set; }
        public int MedicalRecordId { get; set; }
        public int AppointmentId { get; set; }
        public DateTime AppointmentDate { get; set; }
        public string? DoctorName { get; set; }
        public string? Specialization { get; set; }
        public string? Diagnosis { get; set; }
        public string? Therapy { get; set; }
        public string? Notes { get; set; }
        public DateTime CreatedAt { get; set; }
        public PrescriptionResponse? Prescription { get; set; }
    }
}
