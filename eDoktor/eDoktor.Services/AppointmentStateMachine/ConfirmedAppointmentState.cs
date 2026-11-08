using System;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Messages;
using eDoktor.Model.Responses;
using eDoktor.Services.Appointments;
using eDoktor.Services.Database;
using eDoktor.Services.PayPal;
using eDoktor.Services.RabbitMQ;
using eDoktor.Services.Recommender;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace eDoktor.Services.AppointmentStateMachine
{
    public class ConfirmedAppointmentState : BaseAppointmentState
    {
        public ConfirmedAppointmentState(IServiceProvider sp, IMapper mapper, eDoktorDbContext context)
            : base(sp, mapper, context) { }

        public override async Task<AppointmentResponse> CompleteAsync(int id)
        {
            var a = await LoadAsync(id);
            if (a.TimeSlot.StartUtc > DateTime.UtcNow)
                throw new UserException("Pregled se može označiti kao završen tek nakon zakazanog vremena.");
            var actingUserId = await ActingUserIdAsync();
            await InTransactionAsync(async () =>
            {
                a.StateMachine = nameof(CompletedAppointmentState);
                a.CompletedAt = DateTime.UtcNow;
                a.CompletedById = actingUserId;
                await _context.SaveChangesAsync();
                await NotifyAsync(a.PatientId, "Termin završen",
                    $"Vaš termin kod dr. {a.Doctor?.User?.FirstName} {a.Doctor?.User?.LastName} je označen kao završen. Možete ostaviti recenziju.");
            });
            await _serviceProvider.GetRequiredService<IRecommenderService>().InvalidateAsync(a.PatientId);
            return await MapAfterChangeAsync(a);
        }

        public override async Task<AppointmentResponse> CancelAsync(int id, string? reason)
        {
            var a = await LoadAsync(id);
            var hoursUntil = (a.TimeSlot.StartUtc - DateTime.UtcNow).TotalHours;
            var byStaff = await IsStaffAsync();

            // A patient may cancel a confirmed appointment only up to 24h before it (and then gets the money back).
            // When the practice cancels, the patient is always refunded, whenever it happens.
            if (!byStaff && hoursUntil < 24)
                throw new UserException("Otkazivanje nije moguće manje od 24h prije termina.");

            var payment = a.CapturedPayment();
            var refundEligible = payment != null && !string.IsNullOrEmpty(payment.CaptureId);
            var refunded = false;

            // Refund first, outside the DB transaction: an HTTP call to PayPal must not hold the transaction open,
            // and if the refund fails nothing has changed yet, so the appointment can't end up cancelled-but-unrefunded.
            if (refundEligible)
            {
                var logger = _serviceProvider.GetRequiredService<ILogger<ConfirmedAppointmentState>>();
                try
                {
                    var paypal = _serviceProvider.GetRequiredService<IPayPalService>();
                    refunded = await paypal.RefundAsync(payment!.CaptureId!, payment.Amount, "Otkazivanje termina");
                }
                catch (Exception ex)
                {
                    logger.LogWarning(ex, "Refund failed for appointment {AppointmentId} (capture {CaptureId}).", a.Id, payment!.CaptureId);
                }
                if (!refunded)
                    throw new UserException("Povrat novca nije uspio, pa termin nije otkazan. Pokušajte ponovo kasnije.");
            }

            var actingUserId = await ActingUserIdAsync();
            await InTransactionAsync(async () =>
            {
                a.StateMachine = nameof(CancelledAppointmentState);
                a.CancelledAt = DateTime.UtcNow;
                a.CancelledById = actingUserId;
                a.CancellationReason = reason;
                a.TimeSlot.IsBooked = false;
                if (refunded)
                {
                    payment!.Status = PaymentStatus.Refunded;
                    payment.RefundedAt = DateTime.UtcNow;
                }
                await _context.SaveChangesAsync();
                await NotifyAsync(a.PatientId, "Termin otkazan",
                    $"Vaš termin kod dr. {a.Doctor?.User?.FirstName} {a.Doctor?.User?.LastName} ({DisplayTime.Format(a.TimeSlot.StartUtc)}) je otkazan."
                    + (string.IsNullOrWhiteSpace(reason) ? "" : $" Razlog: {reason}")
                    + (refunded ? " Novac je vraćen na vaš PayPal račun." : ""));
                await NotifyDoctorOfCancellationAsync(a, reason, byStaff);
            });

            // Messages leave the system only after the cancellation is committed.
            var rabbit = _serviceProvider.GetRequiredService<IRabbitMQService>();
            await rabbit.PublishAsync(QueueNames.AppointmentCancelled, new AppointmentCancelledMessage
            {
                AppointmentId = a.Id,
                PatientId = a.PatientId,
                DoctorId = a.DoctorId,
                PatientEmail = a.Patient?.Email ?? string.Empty,
                PatientName = $"{a.Patient?.FirstName} {a.Patient?.LastName}".Trim(),
                DoctorName = $"{a.Doctor?.User?.FirstName} {a.Doctor?.User?.LastName}".Trim(),
                StartUtc = a.TimeSlot.StartUtc,
                Reason = reason,
                ShouldRefund = refunded
            });

            return await MapAfterChangeAsync(a);
        }

        public override async Task<AppointmentResponse> RescheduleAsync(int id, int newTimeSlotId, string reason)
            => await MapAfterChangeAsync(await MoveToSlotAsync(id, newTimeSlotId, reason));
    }
}
