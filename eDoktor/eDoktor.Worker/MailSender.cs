using eDoktor.Model.Messages;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Logging;
using MimeKit;

namespace eDoktor.Worker
{
    public static class MailSender
    {
        // Throws on a real send failure so the consumer can retry / dead-letter the message
        // instead of silently swallowing it. In dev mode (no SMTP configured) it logs and returns.
        public static void Send(EmailMessage email, ILogger logger)
        {
            var smtpHost = Environment.GetEnvironmentVariable("_host") ?? "smtp.gmail.com";
            var smtpPort = int.Parse(Environment.GetEnvironmentVariable("_port") ?? "587");
            var emailUsername = Environment.GetEnvironmentVariable("_fromAddress");
            var emailPassword = Environment.GetEnvironmentVariable("_password");

            // Dev mode: if SMTP isn't configured, just log instead of failing.
            if (string.IsNullOrEmpty(emailUsername) || string.IsNullOrEmpty(emailPassword))
            {
                logger.LogInformation("[dev-email] To={To} Subject={Subject}\n{Body}", email.To, email.Subject, email.Body);
                return;
            }

            var msg = new MimeMessage();
            msg.From.Add(new MailboxAddress("eDoktor", emailUsername));
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
                _ => Template($"Pozdrav {email.FirstName}", "Dobrodošli na eDoktor.", "Vaš nalog je spreman, slobodno se prijavite u aplikaciju i odaberite svog ljekara.")
            };
            msg.Body = new TextPart("html") { Text = htmlBody };

            using var client = new SmtpClient();
            client.Connect(smtpHost, smtpPort, SecureSocketOptions.StartTls);
            client.Authenticate(emailUsername, emailPassword);
            client.Send(msg);
            client.Disconnect(true);
            logger.LogInformation("Email sent: {To} / {Subject}", email.To, email.Subject);
        }

        private static string Template(string greeting, string lead, string body) => $@"
<div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; color: #222'>
    <h2 style='color: #0d47a1;'>{greeting},</h2>
    <p style='font-size: 16px; line-height: 1.5;'>{lead}</p>
    <div style='background-color: #f5f5f5; padding: 15px; border-radius: 6px; margin: 20px 0; white-space: pre-wrap;'>{body}</div>
    <p style='margin-top: 30px;'>Tim eDoktor</p>
</div>";
    }
}
