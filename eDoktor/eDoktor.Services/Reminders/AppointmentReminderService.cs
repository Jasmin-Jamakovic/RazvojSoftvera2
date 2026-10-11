using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Messages;
using eDoktor.Services.AppointmentStateMachine;
using eDoktor.Services.Database;
using eDoktor.Services.Notifications;
using eDoktor.Services.RabbitMQ;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace eDoktor.Services.Reminders
{
    // Sends appointment reminders 24 hours and 1 hour before a confirmed appointment:
    // an in-app notification (pushed over SignalR) plus an email through RabbitMQ -> Worker.
    public class AppointmentReminderService : BackgroundService
    {
        private static readonly TimeSpan CheckInterval = TimeSpan.FromMinutes(1);
        private static readonly TimeSpan DayBefore = TimeSpan.FromHours(24);
        private static readonly TimeSpan HourBefore = TimeSpan.FromHours(1);

        private readonly IServiceScopeFactory _scopes;
        private readonly ILogger<AppointmentReminderService> _logger;

        public AppointmentReminderService(IServiceScopeFactory scopes, ILogger<AppointmentReminderService> logger)
        {
            _scopes = scopes;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            using var timer = new PeriodicTimer(CheckInterval);
            do
            {
                try
                {
                    await SendDueRemindersAsync(stoppingToken);
                }
                catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
                {
                    // A failed run is logged and retried on the next tick; it must not stop the service.
                    _logger.LogError(ex, "Sending appointment reminders failed.");
                }
            } while (await timer.WaitForNextTickAsync(stoppingToken));
        }

        private async Task SendDueRemindersAsync(CancellationToken ct)
        {
            using var scope = _scopes.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<eDoktorDbContext>();
            var notifications = scope.ServiceProvider.GetRequiredService<INotificationService>();
            var rabbit = scope.ServiceProvider.GetRequiredService<IRabbitMQService>();

            var now = DateTime.UtcNow;
            var due = await db.Appointments
                .Include(a => a.Patient)
                .Include(a => a.Doctor).ThenInclude(d => d.User)
                .Include(a => a.TimeSlot)
                .Where(a => a.StateMachine == nameof(ConfirmedAppointmentState)
                    && a.TimeSlot.StartUtc > now
                    && ((a.Reminder24hSentAt == null && a.TimeSlot.StartUtc <= now + DayBefore)
                        || (a.Reminder1hSentAt == null && a.TimeSlot.StartUtc <= now + HourBefore)))
                .ToListAsync(ct);

            foreach (var a in due)
            {
                // Within the last hour only the 1h reminder makes sense; the 24h one is then skipped.
                var window = a.TimeSlot.StartUtc <= now + HourBefore ? "1h" : "24h";
                if (window == "1h") a.Reminder1hSentAt = now;
                a.Reminder24hSentAt ??= now;
                await db.SaveChangesAsync(ct);

                var doctorName = $"{a.Doctor.User.FirstName} {a.Doctor.User.LastName}";
                var when = window == "1h" ? "za sat vremena"
                    : DisplayTime.ToLocal(a.TimeSlot.StartUtc).Date == DisplayTime.ToLocal(now).Date ? "danas" : "sutra";
                await notifications.SendAsync(a.PatientId, "Podsjetnik na termin",
                    $"Vaš termin kod dr. {doctorName} je {when} ({DisplayTime.Format(a.TimeSlot.StartUtc)})"
                    + (a.Type == Database.Entities.AppointmentType.Online ? " – online konsultacija." : "."),
                    "appointment");
                await rabbit.PublishAsync(QueueNames.AppointmentReminder, new AppointmentReminderMessage
                {
                    AppointmentId = a.Id,
                    PatientId = a.PatientId,
                    PatientEmail = a.Patient.Email,
                    PatientName = a.Patient.FirstName,
                    DoctorName = doctorName,
                    StartUtc = a.TimeSlot.StartUtc,
                    Window = window
                });
                _logger.LogInformation("Sent {Window} reminder for appointment {AppointmentId}.", window, a.Id);
            }
        }
    }
}
