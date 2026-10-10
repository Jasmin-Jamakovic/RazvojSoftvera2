using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Appointments;
using eDoktor.Services.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [ApiController, Route("api/appointments"), Authorize]
    public class AppointmentsController : ControllerBase
    {
        private readonly IAppointmentService _appts;
        private readonly ICurrentUserService _current;

        public AppointmentsController(IAppointmentService appts, ICurrentUserService current)
        { _appts = appts; _current = current; }

        // Access rules (own appointments for patients and doctors) are enforced in the service.
        [HttpGet]
        public Task<PagedResult<AppointmentResponse>> Get([FromQuery] AppointmentSearchObject s) => _appts.GetAsync(s);

        [HttpGet("{id}")]
        public Task<AppointmentResponse> GetById(int id) => _appts.GetByIdAsync(id);

        [HttpPost, Authorize(Roles = Roles.Patient)]
        public async Task<AppointmentResponse> Create(AppointmentCreateRequest req)
        {
            var uid = await _current.GetUserIdAsync() ?? throw new UserException("Not authenticated");
            return await _appts.CreateAsync(req, uid);
        }

        [HttpPost("{id}/confirm"), Authorize(Roles = Roles.AdminOrDoctor)]
        public Task<AppointmentResponse> Confirm(int id) => _appts.ConfirmAsync(id);

        [HttpPost("{id}/complete"), Authorize(Roles = Roles.AdminOrDoctor)]
        public Task<AppointmentResponse> Complete(int id) => _appts.CompleteAsync(id);

        [HttpPost("{id}/reschedule"), Authorize(Roles = Roles.Admin)]
        public Task<AppointmentResponse> Reschedule(int id, AppointmentRescheduleRequest req) => _appts.RescheduleAsync(id, req);

        [HttpPost("{id}/cancel")]
        public Task<AppointmentResponse> Cancel(int id, AppointmentStatusChangeRequest req) => _appts.CancelAsync(id, req);
    }
}
