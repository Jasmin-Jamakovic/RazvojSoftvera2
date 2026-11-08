using System;
using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Messages;
using eDoktor.Model.Responses;
using eDoktor.Services.Appointments;
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
            var a = await LoadAsync(id);
            // A paid appointment is confirmed by its payment (see PaymentService.CaptureAsync); confirming it by
            // hand would leave it unpaid with no way to pay any more (payment is only offered while Pending).
            if (a.Price > 0 && a.CapturedPayment() == null)
                throw new UserException("Termin se potvrđuje automatski nakon plaćanja.");
            var staffId = await ActingStaffIdAsync();
            await InTransactionAsync(async () =>
            {
                a.StateMachine = nameof(ConfirmedAppointmentState);
                a.ConfirmedAt = DateTime.UtcNow;
                a.ConfirmedById = staffId;
                await _context.SaveChangesAsync();
                await NotifyAsync(a.PatientId, "Termin potvrđen",
                    $"Vaš termin kod dr. {a.Doctor?.User?.FirstName} {a.Doctor?.User?.LastName} ({DisplayTime.Format(a.TimeSlot.StartUtc)}) je potvrđen.");
            });
            return await MapAfterChangeAsync(a);
        }

        public override async Task<AppointmentResponse> CancelAsync(int id, string? reason)
        {
            var a = await LoadAsync(id);
            var actingUserId = await ActingUserIdAsync();
            var byStaff = await IsStaffAsync();
            await InTransactionAsync(async () =>
            {
                a.StateMachine = nameof(CancelledAppointmentState);
                a.CancelledAt = DateTime.UtcNow;
                a.CancelledById = actingUserId;
                a.CancellationReason = reason;
                a.TimeSlot.IsBooked = false;
                // An unfinished PayPal order can't be captured for a cancelled appointment any more.
                foreach (var p in a.Payments.Where(p => p.Status == PaymentStatus.Created))
                    p.Status = PaymentStatus.Cancelled;
                await _context.SaveChangesAsync();
                await NotifyAsync(a.PatientId, "Termin otkazan",
                    $"Vaš termin kod dr. {a.Doctor?.User?.FirstName} {a.Doctor?.User?.LastName} ({DisplayTime.Format(a.TimeSlot.StartUtc)}) je otkazan."
                    + (string.IsNullOrWhiteSpace(reason) ? "" : $" Razlog: {reason}"));
                await NotifyDoctorOfCancellationAsync(a, reason, byStaff);
            });

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

            return await MapAfterChangeAsync(a);
        }

        public override async Task<AppointmentResponse> RescheduleAsync(int id, int newTimeSlotId, string reason)
            => await MapAfterChangeAsync(await MoveToSlotAsync(id, newTimeSlotId, reason));
    }
}
