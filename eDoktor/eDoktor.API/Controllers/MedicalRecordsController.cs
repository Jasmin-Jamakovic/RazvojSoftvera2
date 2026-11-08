using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Auth;
using eDoktor.Services.MedicalRecords;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [ApiController, Route("api/medical-records"), Authorize]
    public class MedicalRecordsController : ControllerBase
    {
        private readonly IMedicalRecordService _svc;
        private readonly ICurrentUserService _current;
        public MedicalRecordsController(IMedicalRecordService s, ICurrentUserService c) { _svc = s; _current = c; }

        private async Task<int> UserIdAsync() => await _current.GetUserIdAsync() ?? throw new UserException("Niste prijavljeni.");

        // ---- the signed-in patient's own record: header + paged lists
        [HttpGet("me")]
        public async Task<MedicalRecordResponse?> Me() => await _svc.GetForPatientAsync(await UserIdAsync());

        [HttpGet("me/entries")]
        public async Task<PagedResult<MedicalRecordEntryResponse>> MyEntries([FromQuery] MedicalRecordSearchObject s)
            => await _svc.GetEntriesAsync(await UserIdAsync(), s);

        [HttpGet("me/prescriptions")]
        public async Task<PagedResult<PrescriptionResponse>> MyPrescriptions([FromQuery] MedicalRecordSearchObject s)
            => await _svc.GetPrescriptionsAsync(await UserIdAsync(), s);

        [HttpGet("me/lab-results")]
        public async Task<PagedResult<LabResultResponse>> MyLabResults([FromQuery] MedicalRecordSearchObject s)
            => await _svc.GetLabResultsAsync(await UserIdAsync(), s);

        // ---- a patient's record, for their doctors and the admin
        [HttpGet("patient/{patientId}"), Authorize(Roles = Roles.AdminOrDoctor)]
        public Task<MedicalRecordResponse?> ForPatient(int patientId) => _svc.GetForPatientAsync(patientId);

        [HttpGet("patient/{patientId}/entries"), Authorize(Roles = Roles.AdminOrDoctor)]
        public Task<PagedResult<MedicalRecordEntryResponse>> PatientEntries(int patientId, [FromQuery] MedicalRecordSearchObject s)
            => _svc.GetEntriesAsync(patientId, s);

        [HttpGet("patient/{patientId}/prescriptions"), Authorize(Roles = Roles.AdminOrDoctor)]
        public Task<PagedResult<PrescriptionResponse>> PatientPrescriptions(int patientId, [FromQuery] MedicalRecordSearchObject s)
            => _svc.GetPrescriptionsAsync(patientId, s);

        [HttpGet("patient/{patientId}/lab-results"), Authorize(Roles = Roles.AdminOrDoctor)]
        public Task<PagedResult<LabResultResponse>> PatientLabResults(int patientId, [FromQuery] MedicalRecordSearchObject s)
            => _svc.GetLabResultsAsync(patientId, s);

        // ---- visits (diagnosis / therapy), written by the appointment's doctor
        [HttpGet("entries/{id}")]
        public Task<MedicalRecordEntryResponse> GetEntry(int id) => _svc.GetEntryAsync(id);

        [HttpPost("entries"), Authorize(Roles = Roles.Doctor)]
        public async Task<MedicalRecordEntryResponse> AddEntry(MedicalRecordEntryUpsertRequest req)
            => await _svc.AddEntryAsync(req, await UserIdAsync());

        [HttpPut("entries/{id}"), Authorize(Roles = Roles.Doctor)]
        public async Task<MedicalRecordEntryResponse> UpdateEntry(int id, MedicalRecordEntryUpsertRequest req)
            => await _svc.UpdateEntryAsync(id, req, await UserIdAsync());

        [HttpDelete("entries/{id}"), Authorize(Roles = Roles.Doctor)]
        public async Task<IActionResult> DeleteEntry(int id)
        {
            await _svc.DeleteEntryAsync(id, await UserIdAsync());
            return NoContent();
        }

        // ---- prescriptions (header + medication rows)
        [HttpGet("prescriptions/{id}")]
        public Task<PrescriptionResponse> GetPrescription(int id) => _svc.GetPrescriptionAsync(id);

        [HttpPost("prescriptions"), Authorize(Roles = Roles.Doctor)]
        public async Task<PrescriptionResponse> AddPrescription(PrescriptionUpsertRequest req)
            => await _svc.AddPrescriptionAsync(req, await UserIdAsync());

        [HttpPut("prescriptions/{id}"), Authorize(Roles = Roles.Doctor)]
        public async Task<PrescriptionResponse> UpdatePrescription(int id, PrescriptionUpsertRequest req)
            => await _svc.UpdatePrescriptionAsync(id, req, await UserIdAsync());

        [HttpDelete("prescriptions/{id}"), Authorize(Roles = Roles.Doctor)]
        public async Task<IActionResult> DeletePrescription(int id)
        {
            await _svc.DeletePrescriptionAsync(id, await UserIdAsync());
            return NoContent();
        }

        // ---- lab results
        [HttpGet("lab-results/{id}")]
        public Task<LabResultResponse> GetLabResult(int id) => _svc.GetLabResultAsync(id);

        [HttpPost("lab-results"), Authorize(Roles = Roles.AdminOrDoctor)]
        public Task<LabResultResponse> AddLabResult(LabResultUpsertRequest req) => _svc.AddLabResultAsync(req);

        [HttpPut("lab-results/{id}"), Authorize(Roles = Roles.AdminOrDoctor)]
        public Task<LabResultResponse> UpdateLabResult(int id, LabResultUpsertRequest req) => _svc.UpdateLabResultAsync(id, req);

        [HttpDelete("lab-results/{id}"), Authorize(Roles = Roles.AdminOrDoctor)]
        public async Task<IActionResult> DeleteLabResult(int id)
        {
            await _svc.DeleteLabResultAsync(id);
            return NoContent();
        }
    }
}
