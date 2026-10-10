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

        [HttpGet]
        public async Task<PagedResult<AppointmentResponse>> Get([FromQuery] AppointmentSearchObject s)
        {
            var role = await _current.GetUserRoleAsync();
            var uid = await _current.GetUserIdAsync();
            if (role == Roles.Patient && uid.HasValue) s.PatientId = uid.Value;
            return await _appts.GetAsync(s ?? new());
        }

        [HttpGet("{id}")]
        public async Task<AppointmentResponse?> GetById(int id)
        {
            var appt = await _appts.GetByIdAsync(id)
                ?? throw new NotFoundException("Appointment not found");
            var role = await _current.GetUserRoleAsync();
            var uid = await _current.GetUserIdAsync();
            if (role == Roles.Patient && appt.PatientId != uid)
                throw new ForbiddenException("You can only view your own appointments.");
            return appt;
        }

        [HttpPost]
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
        public async Task<AppointmentResponse> Cancel(int id, AppointmentStatusChangeRequest req)
        {
            var role = await _current.GetUserRoleAsync();
            var uid = await _current.GetUserIdAsync();
            if (role == Roles.Patient)
            {
                var appt = await _appts.GetByIdAsync(id)
                    ?? throw new NotFoundException("Appointment not found");
                if (appt.PatientId != uid)
                    throw new ForbiddenException("You can only cancel your own appointments.");
            }
            return await _appts.CancelAsync(id, req);
        }
    }
}
