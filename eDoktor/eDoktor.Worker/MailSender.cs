using eDoktor.Model.Messages;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Logging;
using MimeKit;

namespace eDoktor.Worker
{
    // SMTP settings come from .env and are read once. With no sender address/password configured
    // (development), emails are written to the log instead of being sent.
    public class MailSender
    {
        private readonly ILogger _logger;
        private readonly string? _fromAddress;
        private readonly string? _password;
        private readonly string _host = string.Empty;
        private readonly int _port;
        private readonly bool _enableSsl;
        private readonly int _timeoutMs;
        private readonly string _displayName = string.Empty;

        public MailSender(ILogger logger)
        {
            _logger = logger;
            _fromAddress = Environment.GetEnvironmentVariable("_fromAddress");
            _password = Environment.GetEnvironmentVariable("_password");
            if (!IsConfigured) return;

            _host = Required("_host");
            _port = int.Parse(Required("_port"));
            _enableSsl = bool.Parse(Required("_enableSSL"));
            _timeoutMs = int.Parse(Required("_timeout"));
            _displayName = Required("_displayName");
        }

        private bool IsConfigured => !string.IsNullOrEmpty(_fromAddress) && !string.IsNullOrEmpty(_password);

        private static string Required(string name) => Environment.GetEnvironmentVariable(name)
            ?? throw new InvalidOperationException($"{name} is not configured (set it in .env).");

        // Throws on a real send failure so the consumer can retry / dead-letter the message.
        public async Task SendAsync(EmailMessage email)
        {
            if (!IsConfigured)
            {
                _logger.LogInformation("[dev-email] To={To} Subject={Subject}\n{Body}", email.To, email.Subject, email.Body);
                return;
            }

            var msg = new MimeMessage();
            msg.From.Add(new MailboxAddress(_displayName, _fromAddress));
            msg.To.Add(MailboxAddress.Parse(email.To));
            msg.Subject = email.Subject;

            var htmlBody = email.Kind switch
            {
                EmailKind.DoctorCredentials => Template($"Pozdrav {email.FirstName} {email.LastName}", "Vaš eDoktor nalog je kreiran. Pristupne podatke možete promijeniti prilikom prve prijave.", email.Body),
                EmailKind.AppointmentBooked => Template($"Pozdrav {email.FirstName}", "Vaš termin je uspješno zakazan.", email.Body),
                EmailKind.AppointmentCancelled => Template($"Pozdrav {email.FirstName}", "Vaš termin je otkazan.", email.Body),
                EmailKind.AppointmentReminder => Template($"Pozdrav {email.FirstName}", "Podsjetnik na predstojeći termin.", email.Body),
                EmailKind.PaymentReceipt => Template($"Pozdrav {email.FirstName}", "Hvala na uplati putem PayPala.", email.Body),
                EmailKind.PrescriptionIssued => Template($"Pozdrav {email.FirstName}", "Izdat vam je novi e-recept.", email.Body),
                EmailKind.AppointmentRescheduled => Template($"Pozdrav {email.FirstName}", "Vaš termin je pomjeren.", email.Body),
                EmailKind.PasswordReset => Template($"Pozdrav {email.FirstName}", "Zatražili ste resetovanje lozinke.", email.Body),
                _ => Template($"Pozdrav {email.FirstName}", "Dobrodošli na eDoktor.", "Vaš nalog je spreman, slobodno se prijavite u aplikaciju i odaberite svog ljekara.")
            };
            msg.Body = new TextPart("html") { Text = htmlBody };

            using var client = new SmtpClient { Timeout = _timeoutMs };
            await client.ConnectAsync(_host, _port, _enableSsl ? SecureSocketOptions.StartTls : SecureSocketOptions.None);
            await client.AuthenticateAsync(_fromAddress, _password);
            await client.SendAsync(msg);
            await client.DisconnectAsync(true);
            _logger.LogInformation("Email sent: {To} / {Subject}", email.To, email.Subject);
        }

        private static string Template(string greeting, string lead, string body) => $@"
<div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; color: #222'>
    <h2 style='color: #2e7d32;'>{greeting},</h2>
    <p style='font-size: 16px; line-height: 1.5;'>{lead}</p>
    <div style='background-color: #f5f5f5; padding: 15px; border-radius: 6px; margin: 20px 0; white-space: pre-wrap;'>{body}</div>
    <p style='margin-top: 30px;'>Tim eDoktor</p>
</div>";
    }
}
