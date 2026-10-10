using System;
using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.AppointmentStateMachine;
using eDoktor.Services.Auth;
using eDoktor.Services.Database;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace eDoktor.Services.Appointments
{
    // Who may see or change an appointment:
    //  - admin: everything;
    //  - doctor: only their own appointments (view, confirm, complete, cancel with a reason);
    //  - patient: only their own appointments (view, cancel).
    public class AppointmentService : IAppointmentService
    {
        private readonly eDoktorDbContext _db;
        private readonly IServiceProvider _sp;
        private readonly IMapper _mapper;
        private readonly ICurrentUserService _current;

        public AppointmentService(eDoktorDbContext db, IServiceProvider sp, IMapper mapper, ICurrentUserService current)
        { _db = db; _sp = sp; _mapper = mapper; _current = current; }

        private record Caller(string? Role, int? UserId, int? DoctorId);

        private async Task<Caller> CallerAsync()
        {
            var role = await _current.GetUserRoleAsync();
            var uid = await _current.GetUserIdAsync();
            int? doctorId = role == Roles.Doctor
                ? await _db.Doctors.Where(d => d.UserId == uid).Select(d => (int?)d.Id).FirstOrDefaultAsync()
                : null;
            return new Caller(role, uid, doctorId);
        }

        public async Task<PagedResult<AppointmentResponse>> GetAsync(AppointmentSearchObject s)
        {
            var caller = await CallerAsync();
            if (caller.Role == Roles.Patient) s.PatientId = caller.UserId;
            else if (caller.Role == Roles.Doctor) s.DoctorId = caller.DoctorId ?? -1;
            else if (caller.Role != Roles.Admin) throw new ForbiddenException("Nemate pristup terminima.");

            var q = _db.Appointments.WithDetails();
            if (s.PatientId.HasValue) q = q.Where(a => a.PatientId == s.PatientId.Value);
            if (s.DoctorId.HasValue) q = q.Where(a => a.DoctorId == s.DoctorId.Value);
            if (!string.IsNullOrWhiteSpace(s.Status))
                q = q.Where(a => a.StateMachine == s.Status + "AppointmentState");
            if (s.From.HasValue) q = q.Where(a => a.TimeSlot.StartUtc >= s.From.Value);
            if (s.To.HasValue) q = q.Where(a => a.TimeSlot.StartUtc <= s.To.Value);

            q = q.OrderByDescending(a => a.TimeSlot.StartUtc);

            s.Normalize();
            int? total = s.IncludeTotalCount ? await q.CountAsync() : null;
            q = q.Skip(s.Page!.Value * s.PageSize!.Value).Take(s.PageSize!.Value);

            var list = await q.ToListAsync();
            return new PagedResult<AppointmentResponse> { Items = list.Select(a => a.ToResponse(_mapper)).ToList(), TotalCount = total };
        }

        public async Task<AppointmentResponse> GetByIdAsync(int id)
        {
            var a = await _db.Appointments.WithDetails().FirstOrDefaultAsync(a => a.Id == id)
                ?? throw new NotFoundException("Termin nije pronađen.");
            var caller = await CallerAsync();
            if (!IsParticipantOrAdmin(caller, a.PatientId, a.DoctorId))
                throw new ForbiddenException("Nemate pristup ovom terminu.");
            return a.ToResponse(_mapper);
        }

        public Task<AppointmentResponse> CreateAsync(AppointmentCreateRequest req, int patientId)
            => _sp.GetRequiredService<InitialAppointmentState>().CreateAsync(req, patientId);

        public async Task<AppointmentResponse> ConfirmAsync(int id)
        {
            var state = await StateForStaffAsync(id);
            return await state.ConfirmAsync(id);
        }

        public async Task<AppointmentResponse> CompleteAsync(int id)
        {
            var state = await StateForStaffAsync(id);
            return await state.CompleteAsync(id);
        }

        public async Task<AppointmentResponse> CancelAsync(int id, AppointmentStatusChangeRequest req)
        {
            var (a, caller) = await LoadForCallerAsync(id);
            if (!IsParticipantOrAdmin(caller, a.PatientId, a.DoctorId))
                throw new ForbiddenException("Možete otkazati samo vlastite termine.");
            var reason = string.IsNullOrWhiteSpace(req.Reason) ? null : req.Reason.Trim();
            // When the practice cancels, the patient must be told why.
            if (caller.Role != Roles.Patient && reason == null)
                throw new UserException("Unesite razlog otkazivanja – pacijent će ga dobiti u obavještenju.");
            return await StateOf(a.StateMachine).CancelAsync(id, reason);
        }

        public async Task<AppointmentResponse> RescheduleAsync(int id, AppointmentRescheduleRequest req)
        {
            var (a, _) = await LoadForCallerAsync(id);
            return await StateOf(a.StateMachine).RescheduleAsync(id, req.NewTimeSlotId, req.Reason.Trim());
        }

        private async Task<BaseAppointmentState> StateForStaffAsync(int id)
        {
            var (a, caller) = await LoadForCallerAsync(id);
            var allowed = caller.Role == Roles.Admin || (caller.Role == Roles.Doctor && caller.DoctorId == a.DoctorId);
            if (!allowed) throw new ForbiddenException("Samo ljekar ovog termina ili administrator može promijeniti njegov status.");
            return StateOf(a.StateMachine);
        }

        private async Task<((int PatientId, int DoctorId, string StateMachine) Appt, Caller Caller)> LoadForCallerAsync(int id)
        {
            var a = await _db.Appointments.Where(x => x.Id == id)
                .Select(x => new { x.PatientId, x.DoctorId, x.StateMachine })
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("Termin nije pronađen.");
            return ((a.PatientId, a.DoctorId, a.StateMachine), await CallerAsync());
        }

        private static bool IsParticipantOrAdmin(Caller c, int patientId, int doctorId) =>
            c.Role == Roles.Admin
            || (c.Role == Roles.Patient && c.UserId == patientId)
            || (c.Role == Roles.Doctor && c.DoctorId == doctorId);

        private BaseAppointmentState StateOf(string stateMachine)
            => _sp.GetRequiredService<InitialAppointmentState>().GetState(stateMachine);
    }
}
