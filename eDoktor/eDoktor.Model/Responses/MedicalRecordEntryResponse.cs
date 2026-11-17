using System;

namespace eDoktor.Model.Responses
{
    public class MedicalRecordEntryResponse
    {
        public int Id { get; set; }
        public int MedicalRecordId { get; set; }
        public int PatientId { get; set; }
        public int AppointmentId { get; set; }
        public int DoctorId { get; set; }
        public DateTime AppointmentDate { get; set; }
        // State of the visit's appointment (Confirmed/Completed/Cancelled...): the desktop offers a prescription only for a valid exam.
        public string? AppointmentStatus { get; set; }
        public string? DoctorName { get; set; }
        public string? Specialization { get; set; }
        public string? Diagnosis { get; set; }
        public string? Therapy { get; set; }
        public string? Notes { get; set; }
        public DateTime CreatedAt { get; set; }
        public PrescriptionResponse? Prescription { get; set; }
    }
}
