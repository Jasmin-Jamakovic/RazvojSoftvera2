using System;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Messages;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Services.Appointments;
using eDoktor.Services.Auth;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using eDoktor.Services.Notifications;
using eDoktor.Services.RabbitMQ;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace eDoktor.Services.AppointmentStateMachine
{
    public class BaseAppointmentState
    {
        protected readonly IServiceProvider _serviceProvider;
        protected readonly IMapper _mapper;
        protected readonly eDoktorDbContext _context;

        public BaseAppointmentState(IServiceProvider sp, IMapper mapper, eDoktorDbContext context)
        {
            _serviceProvider = sp;
            _mapper = mapper;
            _context = context;
        }

        protected Task<Appointment> LoadAsync(int id) => LoadOrThrowAsync(id);

        private async Task<Appointment> LoadOrThrowAsync(int id) =>
            await _context.Appointments.WithDetails().FirstOrDefaultAsync(x => x.Id == id)
            ?? throw new NotFoundException("Termin nije pronađen.");

        protected AppointmentResponse Map(Appointment a) => a.ToResponse(_mapper);

        /// Maps after a transition, loading the audit users that were just assigned so their names are returned.
        protected async Task<AppointmentResponse> MapAfterChangeAsync(Appointment a)
        {
            var entry = _context.Entry(a);
            await entry.Reference(x => x.ConfirmedBy).LoadAsync();
            await entry.Reference(x => x.CompletedBy).LoadAsync();
            await entry.Reference(x => x.CancelledBy).LoadAsync();
            await entry.Reference(x => x.RescheduledBy).LoadAsync();
            return Map(a);
        }

        /// The signed-in user performing the transition (for the audit trail).
        protected Task<int?> ActingUserIdAsync() => _serviceProvider.GetRequiredService<ICurrentUserService>().GetUserIdAsync();

        /// Staff (admin/doctor) performing the transition; null when it happens on the patient's behalf
        /// (e.g. the automatic confirmation after a PayPal payment).
        protected async Task<int?> ActingStaffIdAsync()
        {
            var current = _serviceProvider.GetRequiredService<ICurrentUserService>();
            var role = await current.GetUserRoleAsync();
            return role == Roles.Admin || role == Roles.Doctor ? await current.GetUserIdAsync() : null;
        }

        public virtual Task<AppointmentResponse> CreateAsync(AppointmentCreateRequest req, int patientId)
            => throw new UserException("Termin se ne može zakazati u trenutnom stanju.");

        public virtual Task<AppointmentResponse> ConfirmAsync(int id)
            => throw new UserException("Termin se ne može potvrditi u trenutnom stanju.");

        public virtual Task<AppointmentResponse> CompleteAsync(int id)
            => throw new UserException("Termin se ne može završiti u trenutnom stanju.");

        public virtual Task<AppointmentResponse> CancelAsync(int id, string? reason)
            => throw new UserException("Termin se ne može otkazati u trenutnom stanju.");

        public virtual Task<AppointmentResponse> RescheduleAsync(int id, int newTimeSlotId, string reason)
            => throw new UserException("Samo zakazani ili potvrđeni termini mogu biti pomjereni.");

        /// Moves an active (Pending/Confirmed) appointment to another free slot of the same doctor.
        /// The status is kept; only the slot changes. Old slot is released, new one booked atomically.
        protected async Task<Appointment> MoveToSlotAsync(int id, int newTimeSlotId, string reason)
        {
            var a = await LoadAsync(id);

            if (a.TimeSlot.StartUtc <= DateTime.UtcNow)
                throw new UserException("Termin koji je već počeo ili prošao ne može biti pomjeren.");
            if (a.TimeSlotId == newTimeSlotId)
                throw new UserException("Odaberite termin različit od trenutnog.");

            var newSlot = await _context.TimeSlots.FirstOrDefaultAsync(t => t.Id == newTimeSlotId)
                ?? throw new NotFoundException("Odabrani termin ne postoji.");
            if (newSlot.DoctorId != a.DoctorId)
                throw new UserException("Novi termin mora biti kod istog ljekara.");
            if (newSlot.IsBooked)
                throw new UserException("Odabrani termin je već zauzet.");
            if (newSlot.StartUtc <= DateTime.UtcNow)
                throw new UserException("Termin nije moguće pomjeriti u prošlost.");

            var oldStart = a.TimeSlot.StartUtc;

            var doctorName = $"{a.Doctor.User.FirstName} {a.Doctor.User.LastName}";
            var text = $"Vaš termin kod dr. {doctorName} je pomjeren sa {DisplayTime.Format(oldStart)} na {DisplayTime.Format(newSlot.StartUtc)}. Razlog: {reason}";
            var actingUserId = await ActingUserIdAsync();

            // Slot swap + in-app notification are several SaveChanges calls; commit them together.
            await InTransactionAsync(async () =>
            {
                a.TimeSlot.IsBooked = false;
                newSlot.IsBooked = true;
                a.TimeSlotId = newSlot.Id;
                a.TimeSlot = newSlot;
                a.RescheduledAt = DateTime.UtcNow;
                a.RescheduledById = actingUserId;
                a.RescheduleReason = reason;
                await _context.SaveChangesAsync();
                await NotifyAsync(a.PatientId, "Termin pomjeren", text);
            });

            var rabbit = _serviceProvider.GetRequiredService<IRabbitMQService>();
            await rabbit.PublishAsync(QueueNames.Email, new EmailMessage
            {
                To = a.Patient.Email,
                FirstName = a.Patient.FirstName,
                LastName = a.Patient.LastName,
                Subject = "eDoktor - termin pomjeren",
                Body = text,
                Kind = EmailKind.AppointmentRescheduled
            });

            return a;
        }

        /// Runs several saves (state change, payment, in-app notification) as one transaction. Joins the
        /// caller's transaction when there already is one (e.g. the payment capture confirming an appointment).
        protected async Task InTransactionAsync(Func<Task> work)
        {
            if (_context.Database.CurrentTransaction != null)
            {
                await work();
                return;
            }
            await using var tx = await _context.Database.BeginTransactionAsync();
            await work();
            await tx.CommitAsync();
        }

        /// Creates an in-app notification (persisted + pushed over SignalR) for a user.
        protected async Task NotifyAsync(int userId, string title, string body, string type = "appointment")
        {
            var notifications = _serviceProvider.GetRequiredService<INotificationService>();
            await notifications.SendAsync(userId, title, body, type);
        }

        public BaseAppointmentState GetState(string name) => name switch
        {
            nameof(InitialAppointmentState) => _serviceProvider.GetRequiredService<InitialAppointmentState>(),
            nameof(PendingAppointmentState) => _serviceProvider.GetRequiredService<PendingAppointmentState>(),
            nameof(ConfirmedAppointmentState) => _serviceProvider.GetRequiredService<ConfirmedAppointmentState>(),
            nameof(CompletedAppointmentState) => _serviceProvider.GetRequiredService<CompletedAppointmentState>(),
            nameof(CancelledAppointmentState) => _serviceProvider.GetRequiredService<CancelledAppointmentState>(),
            _ => throw new UserException($"Nepoznato stanje termina: {name}")
        };
    }
}
