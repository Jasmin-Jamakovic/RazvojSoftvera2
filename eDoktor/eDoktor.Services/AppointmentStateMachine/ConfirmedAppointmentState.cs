using System;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Messages;
using eDoktor.Model.Responses;
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
            if (a.TimeSlot?.StartUtc > DateTime.UtcNow)
                throw new UserException("Appointment cannot be completed before its scheduled time");
            a.StateMachine = nameof(CompletedAppointmentState);
            a.CompletedAt = DateTime.UtcNow;
            a.CompletedById = await ActingUserIdAsync();
            await _context.SaveChangesAsync();
            await _serviceProvider.GetRequiredService<IRecommenderService>().InvalidateAsync(a.PatientId);
            await NotifyAsync(a.PatientId, "Termin završen",
                $"Vaš termin kod dr. {a.Doctor?.User?.FirstName} {a.Doctor?.User?.LastName} je označen kao završen. Možete ostaviti recenziju.");
            return await MapAfterChangeAsync(a);
        }

        public override async Task<AppointmentResponse> CancelAsync(int id, string? reason)
        {
            var a = await LoadAsync(id);
            var hoursUntil = a.TimeSlot != null ? (a.TimeSlot.StartUtc - DateTime.UtcNow).TotalHours : 0;
            var refundEligible = hoursUntil >= 24 && a.Payment?.Status == PaymentStatus.Captured;
            var shouldRefund = refundEligible;

            a.StateMachine = nameof(CancelledAppointmentState);
            a.CancelledAt = DateTime.UtcNow;
            a.CancelledById = await ActingUserIdAsync();
            a.CancellationReason = reason;
            if (a.TimeSlot != null) a.TimeSlot.IsBooked = false;
            await _context.SaveChangesAsync();

            // Actually issue the PayPal refund (not just promise it by email) when eligible,
            // then record the refund on our payment row (the gateway itself does no DB work).
            // A failed refund must not undo the cancellation: it is logged and the payment stays "Captured",
            // so the admin can refund it manually from the payments screen.
            if (shouldRefund && !string.IsNullOrEmpty(a.Payment?.CaptureId))
            {
                var logger = _serviceProvider.GetRequiredService<ILogger<ConfirmedAppointmentState>>();
                try
                {
                    var paypal = _serviceProvider.GetRequiredService<IPayPalService>();
                    if (await paypal.RefundAsync(a.Payment.CaptureId, a.Payment.Amount, "Otkazivanje termina (≥24h prije termina)"))
                    {
                        a.Payment.Status = PaymentStatus.Refunded;
                        a.Payment.RefundedAt = DateTime.UtcNow;
                        await _context.SaveChangesAsync();
                    }
                    else
                    {
                        logger.LogWarning("PayPal refused the automatic refund for appointment {AppointmentId} (capture {CaptureId}).", a.Id, a.Payment.CaptureId);
                        shouldRefund = false;
                    }
                }
                catch (Exception ex)
                {
                    logger.LogWarning(ex, "Automatic refund failed for appointment {AppointmentId} (capture {CaptureId}).", a.Id, a.Payment.CaptureId);
                    shouldRefund = false;
                }
            }

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
                ShouldRefund = shouldRefund
            });

            await NotifyAsync(a.PatientId, "Termin otkazan",
                $"Vaš termin kod dr. {a.Doctor?.User?.FirstName} {a.Doctor?.User?.LastName} ({a.TimeSlot?.StartUtc:dd.MM.yyyy. HH:mm}) je otkazan."
                + (string.IsNullOrWhiteSpace(reason) ? "" : $" Razlog: {reason}")
                + (shouldRefund ? " Novac je vraćen na vaš PayPal račun."
                   : refundEligible ? " Povrat sredstava će biti izvršen naknadno." : ""));

            return await MapAfterChangeAsync(a);
        }

        public override async Task<AppointmentResponse> RescheduleAsync(int id, int newTimeSlotId, string reason)
            => await MapAfterChangeAsync(await MoveToSlotAsync(id, newTimeSlotId, reason));
    }
}
