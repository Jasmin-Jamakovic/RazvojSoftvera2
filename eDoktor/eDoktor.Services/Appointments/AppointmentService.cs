using System;
using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.AppointmentStateMachine;
using eDoktor.Services.Database;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace eDoktor.Services.Appointments
{
    public class AppointmentService : IAppointmentService
    {
        private readonly eDoktorDbContext _db;
        private readonly IServiceProvider _sp;
        private readonly IMapper _mapper;

        public AppointmentService(eDoktorDbContext db, IServiceProvider sp, IMapper mapper)
        { _db = db; _sp = sp; _mapper = mapper; }

        public async Task<PagedResult<AppointmentResponse>> GetAsync(AppointmentSearchObject s)
        {
            var q = _db.Appointments
                .Include(a => a.Patient)
                .Include(a => a.Doctor).ThenInclude(d => d.User)
                .Include(a => a.TimeSlot)
                .Include(a => a.Payment)
                .Include(a => a.VideoCallSession)
                .AsQueryable();

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
            return new PagedResult<AppointmentResponse> { Items = list.Select(Map).ToList(), TotalCount = total };
        }

        public async Task<AppointmentResponse?> GetByIdAsync(int id)
        {
            var a = await _db.Appointments
                .Include(a => a.Patient)
                .Include(a => a.Doctor).ThenInclude(d => d.User)
                .Include(a => a.TimeSlot)
                .Include(a => a.Payment)
                .Include(a => a.VideoCallSession)
                .FirstOrDefaultAsync(a => a.Id == id);
            return a == null ? null : Map(a);
        }

        public Task<AppointmentResponse> CreateAsync(AppointmentCreateRequest req, int patientId)
            => _sp.GetRequiredService<InitialAppointmentState>().CreateAsync(req, patientId);

        public async Task<AppointmentResponse> ConfirmAsync(int id)
        {
            var name = await _db.Appointments.Where(a => a.Id == id).Select(a => a.StateMachine).FirstAsync();
            var state = _sp.GetRequiredService<InitialAppointmentState>().GetState(name);
            return await state.ConfirmAsync(id);
        }

        public async Task<AppointmentResponse> CompleteAsync(int id)
        {
            var name = await _db.Appointments.Where(a => a.Id == id).Select(a => a.StateMachine).FirstAsync();
            var state = _sp.GetRequiredService<InitialAppointmentState>().GetState(name);
            return await state.CompleteAsync(id);
        }

        public async Task<AppointmentResponse> CancelAsync(int id, AppointmentStatusChangeRequest req)
        {
            var name = await _db.Appointments.Where(a => a.Id == id).Select(a => a.StateMachine).FirstAsync();
            var state = _sp.GetRequiredService<InitialAppointmentState>().GetState(name);
            return await state.CancelAsync(id, req.Reason);
        }

        public async Task<AppointmentResponse> RescheduleAsync(int id, AppointmentRescheduleRequest req)
        {
            var name = await _db.Appointments.Where(a => a.Id == id).Select(a => a.StateMachine).FirstOrDefaultAsync()
                ?? throw new NotFoundException("Termin nije pronađen.");
            var state = _sp.GetRequiredService<InitialAppointmentState>().GetState(name);
            return await state.RescheduleAsync(id, req.NewTimeSlotId, req.Reason.Trim());
        }

        private AppointmentResponse Map(Database.Entities.Appointment a) => new()
        {
            Id = a.Id,
            PatientId = a.PatientId,
            PatientName = $"{a.Patient?.FirstName} {a.Patient?.LastName}",
            DoctorId = a.DoctorId,
            DoctorName = $"{a.Doctor?.User?.FirstName} {a.Doctor?.User?.LastName}",
            TimeSlotId = a.TimeSlotId,
            StartUtc = a.TimeSlot?.StartUtc ?? DateTime.MinValue,
            EndUtc = a.TimeSlot?.EndUtc ?? DateTime.MinValue,
            Type = (int)a.Type,
            Status = a.StateMachine.Replace("AppointmentState", string.Empty),
            Price = a.Price,
            CreatedAt = a.CreatedAt,
            CancelledAt = a.CancelledAt,
            CancellationReason = a.CancellationReason,
            Payment = a.Payment == null ? null : _mapper.Map<PaymentResponse>(a.Payment),
            VideoRoomId = a.VideoCallSession?.RoomId
        };
    }
}
