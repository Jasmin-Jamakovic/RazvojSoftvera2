using System;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Messages;
using eDoktor.Model.Responses;
using eDoktor.Services.Database;
using eDoktor.Services.RabbitMQ;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace eDoktor.Services.AppointmentStateMachine
{
    public class PendingAppointmentState : BaseAppointmentState
    {
        public PendingAppointmentState(IServiceProvider sp, IMapper mapper, eDoktorDbContext context)
            : base(sp, mapper, context) { }

        public override async Task<AppointmentResponse> ConfirmAsync(int id)
        {
            var a = await Load(id) ?? throw new UserException("Appointment not found");
            a.StateMachine = nameof(ConfirmedAppointmentState);
            await _context.SaveChangesAsync();
            await NotifyAsync(a.PatientId, "Termin potvrđen",
                $"Vaš termin kod dr. {a.Doctor?.User?.FirstName} {a.Doctor?.User?.LastName} ({a.TimeSlot?.StartUtc:dd.MM.yyyy. HH:mm}) je potvrđen.");
            return Map(a);
        }

        public override async Task<AppointmentResponse> CancelAsync(int id, string? reason)
        {
            var a = await Load(id) ?? throw new UserException("Appointment not found");
            a.StateMachine = nameof(CancelledAppointmentState);
            a.CancelledAt = DateTime.UtcNow;
            a.CancellationReason = reason;
            if (a.TimeSlot != null) a.TimeSlot.IsBooked = false;
            await _context.SaveChangesAsync();

            var rabbit = _serviceProvider.GetRequiredService<IRabbitMQService>();
            await rabbit.PublishAsync(QueueNames.AppointmentCancelled, new AppointmentCancelledMessage
            {
                AppointmentId = a.Id,
                PatientId = a.PatientId,
                DoctorId = a.DoctorId,
                PatientEmail = a.Patient?.Email ?? string.Empty,
                PatientName = $"{a.Patient?.FirstName} {a.Patient?.LastName}".Trim(),
                DoctorName = $"{a.Doctor?.User?.FirstName} {a.Doctor?.User?.LastName}".Trim(),
                StartUtc = a.TimeSlot?.StartUtc ?? DateTime.MinValue,
                Reason = reason,
                ShouldRefund = false
            });

            await NotifyAsync(a.PatientId, "Termin otkazan",
                $"Vaš termin kod dr. {a.Doctor?.User?.FirstName} {a.Doctor?.User?.LastName} ({a.TimeSlot?.StartUtc:dd.MM.yyyy. HH:mm}) je otkazan."
                + (string.IsNullOrWhiteSpace(reason) ? "" : $" Razlog: {reason}"));

            return Map(a);
        }

        public override async Task<AppointmentResponse> RescheduleAsync(int id, int newTimeSlotId, string reason)
            => Map(await MoveToSlotAsync(id, newTimeSlotId, reason));

        private Task<Database.Entities.Appointment?> Load(int id) =>
            _context.Appointments
                .Include(x => x.Patient)
                .Include(x => x.Doctor).ThenInclude(d => d.User)
                .Include(x => x.TimeSlot)
                .Include(x => x.Payment)
                .FirstOrDefaultAsync(x => x.Id == id);

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
            Payment = a.Payment == null ? null : _mapper.Map<PaymentResponse>(a.Payment)
        };
    }
}
