using eDoktor.Model;
using System.Collections.Generic;
using System.Threading.Tasks;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Auth;
using eDoktor.Services.Doctors;
using eDoktor.Services.Recommender;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [ApiController, Route("api/doctors"), Authorize]
    public class DoctorsController : ControllerBase
    {
        private readonly IDoctorService _doctors;
        private readonly IRecommenderService _recommender;
        private readonly ICurrentUserService _current;

        public DoctorsController(IDoctorService doctors, IRecommenderService recommender, ICurrentUserService current)
        { _doctors = doctors; _recommender = recommender; _current = current; }

        [HttpGet]
        public Task<PagedResult<DoctorResponse>> Get([FromQuery] DoctorSearchObject s) => _doctors.GetAsync(s ?? new());

        [HttpGet("{id}")]
        public Task<DoctorResponse?> GetById(int id) => _doctors.GetByIdAsync(id);

        // Serves the doctor photo separately so list endpoints don't carry image blobs (spec §8.2).
        [HttpGet("{id}/photo")]
        public async Task<IActionResult> Photo(int id)
        {
            var d = await _doctors.GetByIdAsync(id);
            if (d?.ProfilePhoto == null || d.ProfilePhoto.Length == 0) return NotFound();
            return File(d.ProfilePhoto, ImageValidation.DetectContentType(d.ProfilePhoto) ?? "application/octet-stream");
        }

        [HttpPost, Authorize(Roles = Roles.Admin)]
        public Task<DoctorResponse> Create(DoctorUpsertRequest req) => _doctors.CreateAsync(req);

        [HttpPut("{id}"), Authorize(Roles = Roles.Admin)]
        public Task<DoctorResponse> Update(int id, DoctorUpsertRequest req) => _doctors.UpdateAsync(id, req);

        [HttpDelete("{id}"), Authorize(Roles = Roles.Admin)]
        public Task<bool> Delete(int id) => _doctors.SoftDeleteAsync(id);

        [HttpGet("recommended")]
        public async Task<List<DoctorResponse>> Recommended([FromQuery] int n = 10)
        {
            var uid = await _current.GetUserIdAsync();
            if (!uid.HasValue) return new();
            return await _recommender.GetRecommendedAsync(uid.Value, n);
        }
    }
}
