using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
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

        [HttpGet("me")]
        public async Task<MedicalRecordResponse?> Me()
        {
            var uid = await _current.GetUserIdAsync() ?? throw new UserException("Niste prijavljeni.");
            return await _svc.GetForPatientAsync(uid);
        }

        [HttpGet("patient/{patientId}"), Authorize(Roles = Roles.AdminOrDoctor)]
        public Task<MedicalRecordResponse?> ForPatient(int patientId) => _svc.GetForPatientAsync(patientId);

        [HttpPost("entries"), Authorize(Roles = Roles.Doctor)]
        public async Task<MedicalRecordEntryResponse> AddEntry(MedicalRecordEntryUpsertRequest req)
        {
            var uid = await _current.GetUserIdAsync() ?? throw new UserException("Niste prijavljeni.");
            return await _svc.AddEntryAsync(req, uid);
        }

        [HttpPost("prescriptions"), Authorize(Roles = Roles.Doctor)]
        public async Task<PrescriptionResponse> AddPrescription(PrescriptionUpsertRequest req)
        {
            var uid = await _current.GetUserIdAsync() ?? throw new UserException("Niste prijavljeni.");
            return await _svc.AddPrescriptionAsync(req, uid);
        }

        [HttpPost("lab-results"), Authorize(Roles = Roles.AdminOrDoctor)]
        public Task<LabResultResponse> AddLabResult(LabResultUpsertRequest req) => _svc.AddLabResultAsync(req);
    }
}
