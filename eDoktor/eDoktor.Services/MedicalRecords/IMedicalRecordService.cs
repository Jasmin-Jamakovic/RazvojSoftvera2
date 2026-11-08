using System.Threading.Tasks;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;

namespace eDoktor.Services.MedicalRecords
{
    public interface IMedicalRecordService
    {
        Task<MedicalRecordResponse?> GetForPatientAsync(int patientId);
        Task<PagedResult<MedicalRecordEntryResponse>> GetEntriesAsync(int patientId, MedicalRecordSearchObject search);
        Task<PagedResult<PrescriptionResponse>> GetPrescriptionsAsync(int patientId, MedicalRecordSearchObject search);
        Task<PagedResult<LabResultResponse>> GetLabResultsAsync(int patientId, MedicalRecordSearchObject search);

        Task<MedicalRecordEntryResponse> GetEntryAsync(int id);
        Task<MedicalRecordEntryResponse> AddEntryAsync(MedicalRecordEntryUpsertRequest req, int doctorUserId);
        Task<MedicalRecordEntryResponse> UpdateEntryAsync(int id, MedicalRecordEntryUpsertRequest req, int doctorUserId);
        Task DeleteEntryAsync(int id, int doctorUserId);

        Task<PrescriptionResponse> GetPrescriptionAsync(int id);
        Task<PrescriptionResponse> AddPrescriptionAsync(PrescriptionUpsertRequest req, int doctorUserId);
        Task<PrescriptionResponse> UpdatePrescriptionAsync(int id, PrescriptionUpsertRequest req, int doctorUserId);
        Task DeletePrescriptionAsync(int id, int doctorUserId);

        Task<LabResultResponse> GetLabResultAsync(int id);
        Task<LabResultResponse> AddLabResultAsync(LabResultUpsertRequest req);
        Task<LabResultResponse> UpdateLabResultAsync(int id, LabResultUpsertRequest req);
        Task DeleteLabResultAsync(int id);
    }
}
