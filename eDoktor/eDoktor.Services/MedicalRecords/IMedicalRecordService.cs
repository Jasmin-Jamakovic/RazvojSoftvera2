using System.Threading.Tasks;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;

namespace eDoktor.Services.MedicalRecords
{
    public interface IMedicalRecordService
    {
        Task<MedicalRecordResponse?> GetForPatientAsync(int patientId);
        Task<MedicalRecordEntryResponse> AddEntryAsync(MedicalRecordEntryUpsertRequest req, int doctorUserId);
        Task<PrescriptionResponse> AddPrescriptionAsync(PrescriptionUpsertRequest req, int doctorUserId);
        Task<LabResultResponse> AddLabResultAsync(LabResultUpsertRequest req);
    }
}
