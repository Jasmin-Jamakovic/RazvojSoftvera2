using System;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Messages;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Services.Database;
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

        public virtual Task<AppointmentResponse> CreateAsync(AppointmentCreateRequest req, int patientId)
            => throw new UserException("Cannot create from current state");

        public virtual Task<AppointmentResponse> ConfirmAsync(int id)
            => throw new UserException("Cannot confirm from current state");

        public virtual Task<AppointmentResponse> CompleteAsync(int id)
            => throw new UserException("Cannot complete from current state");

        public virtual Task<AppointmentResponse> CancelAsync(int id, string? reason)
            => throw new UserException("Cannot cancel from current state");

        public virtual Task<AppointmentResponse> RescheduleAsync(int id, int newTimeSlotId, string reason)
            => throw new UserException("Samo zakazani ili potvrđeni termini mogu biti pomjereni.");

        /// Moves an active (Pending/Confirmed) appointment to another free slot of the same doctor.
        /// The status is kept; only the slot changes. Old slot is released, new one booked atomically.
        protected async Task<Database.Entities.Appointment> MoveToSlotAsync(int id, int newTimeSlotId, string reason)
        {
            var a = await _context.Appointments
                .Include(x => x.Patient)
                .Include(x => x.Doctor).ThenInclude(d => d.User)
                .Include(x => x.TimeSlot)
                .Include(x => x.Payment)
                .Include(x => x.VideoCallSession)
                .FirstOrDefaultAsync(x => x.Id == id)
                ?? throw new NotFoundException("Termin nije pronađen.");

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

            // Slot swap + in-app notification are several SaveChanges calls; commit them together.
            await using var tx = await _context.Database.BeginTransactionAsync();
            a.TimeSlot.IsBooked = false;
            newSlot.IsBooked = true;
            a.TimeSlotId = newSlot.Id;
            a.TimeSlot = newSlot;
            await _context.SaveChangesAsync();

            var doctorName = $"{a.Doctor.User.FirstName} {a.Doctor.User.LastName}";
            var text = $"Vaš termin kod dr. {doctorName} je pomjeren sa {oldStart:dd.MM.yyyy. HH:mm} na {newSlot.StartUtc:dd.MM.yyyy. HH:mm}. Razlog: {reason}";
            await NotifyAsync(a.PatientId, "Termin pomjeren", text);
            await tx.CommitAsync();

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
            _ => throw new UserException($"Unknown state {name}")
        };
    }
}
