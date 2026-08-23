using System.Text;
using DotNetEnv;
using eDoktor.Model.Messages;
using eDoktor.Worker;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

Env.Load();

using var loggerFactory = LoggerFactory.Create(b =>
    b.AddSimpleConsole(o => { o.TimestampFormat = "HH:mm:ss "; o.SingleLine = true; }));
var logger = loggerFactory.CreateLogger("eDoktor.Worker");

var hostname = Environment.GetEnvironmentVariable("_rabbitMqHost") ?? "rabbitmq";
var username = Environment.GetEnvironmentVariable("_rabbitMqUser")
    ?? throw new InvalidOperationException("_rabbitMqUser is not configured.");
var password = Environment.GetEnvironmentVariable("_rabbitMqPassword")
    ?? throw new InvalidOperationException("_rabbitMqPassword is not configured.");
var port = int.Parse(Environment.GetEnvironmentVariable("_rabbitMqPort") ?? "5672");

// Connect with exponential backoff (no Thread.Sleep / .Wait()).
IConnection? connection = null;
var connectDelay = TimeSpan.FromSeconds(1);
for (var attempt = 1; attempt <= 10 && connection == null; attempt++)
{
    try
    {
        var factory = new ConnectionFactory
        {
            HostName = hostname, Port = port, UserName = username, Password = password,
            RequestedConnectionTimeout = TimeSpan.FromSeconds(30),
            DispatchConsumersAsync = true
        };
        connection = factory.CreateConnection();
        logger.LogInformation("Connected to RabbitMQ at {Host}:{Port}.", hostname, port);
    }
    catch (Exception ex)
    {
        logger.LogWarning(ex, "RabbitMQ connect attempt {Attempt} failed; retrying in {Delay}s.",
            attempt, connectDelay.TotalSeconds);
        await Task.Delay(connectDelay);
        connectDelay = TimeSpan.FromSeconds(Math.Min(connectDelay.TotalSeconds * 2, 30));
    }
}
if (connection == null) { logger.LogError("Giving up on RabbitMQ after 10 attempts."); Environment.Exit(1); }

var channel = connection!.CreateModel();
channel.BasicQos(prefetchSize: 0, prefetchCount: 1, global: false);

// Manual-ack async consumer: process with in-handler retry + exponential backoff,
// ack on success, nack (no requeue -> dead-letter) after retries are exhausted so a
// poison message can't spin forever, but a transient failure is retried and never lost silently.
void DeclareAndConsume(string queue, Func<string, Task> handler)
{
    channel.QueueDeclare(queue, durable: false, exclusive: false, autoDelete: false, arguments: null);
    var consumer = new AsyncEventingBasicConsumer(channel);
    consumer.Received += async (_, ea) =>
    {
        var body = Encoding.UTF8.GetString(ea.Body.ToArray());
        var delay = TimeSpan.FromSeconds(1);
        for (var attempt = 1; ; attempt++)
        {
            try
            {
                await handler(body);
                channel.BasicAck(ea.DeliveryTag, multiple: false);
                return;
            }
            catch (Exception ex) when (attempt < 4)
            {
                logger.LogWarning(ex, "[{Queue}] processing failed (attempt {Attempt}); retrying in {Delay}s.",
                    queue, attempt, delay.TotalSeconds);
                await Task.Delay(delay);
                delay = TimeSpan.FromSeconds(delay.TotalSeconds * 2);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "[{Queue}] giving up after retries; message dead-lettered.", queue);
                channel.BasicNack(ea.DeliveryTag, multiple: false, requeue: false);
                return;
            }
        }
    };
    channel.BasicConsume(queue: queue, autoAck: false, consumer: consumer);
    logger.LogInformation("Listening on '{Queue}'.", queue);
}

DeclareAndConsume(QueueNames.Email, body =>
{
    var msg = JsonConvert.DeserializeObject<EmailMessage>(body)!;
    MailSender.Send(msg, logger);
    return Task.CompletedTask;
});

DeclareAndConsume(QueueNames.AppointmentBooked, body =>
{
    var m = JsonConvert.DeserializeObject<AppointmentBookedMessage>(body)!;
    MailSender.Send(new EmailMessage
    {
        To = m.PatientEmail,
        FirstName = m.PatientName,
        Subject = "Vaš termin je zakazan",
        Body = $"Zakazali ste termin kod {m.DoctorName} na {m.StartUtc:g} ({m.Type}).",
        Kind = EmailKind.AppointmentBooked
    }, logger);
    return Task.CompletedTask;
});

DeclareAndConsume(QueueNames.AppointmentCancelled, body =>
{
    var m = JsonConvert.DeserializeObject<AppointmentCancelledMessage>(body)!;
    MailSender.Send(new EmailMessage
    {
        To = m.PatientEmail,
        FirstName = m.PatientName,
        Subject = "Vaš termin je otkazan",
        Body = $"Termin kod {m.DoctorName} ({m.StartUtc:g}) je otkazan. {(m.ShouldRefund ? "Povrat sredstava će biti obrađen." : "")}",
        Kind = EmailKind.AppointmentCancelled
    }, logger);
    return Task.CompletedTask;
});

DeclareAndConsume(QueueNames.AppointmentReminder, body =>
{
    var m = JsonConvert.DeserializeObject<AppointmentReminderMessage>(body)!;
    MailSender.Send(new EmailMessage
    {
        To = m.PatientEmail,
        FirstName = m.PatientName,
        Subject = $"Podsjetnik na termin ({m.Window})",
        Body = $"Imate termin kod {m.DoctorName} na {m.StartUtc:g}.",
        Kind = EmailKind.AppointmentReminder
    }, logger);
    return Task.CompletedTask;
});

DeclareAndConsume(QueueNames.PaymentCaptured, body =>
{
    var m = JsonConvert.DeserializeObject<PaymentCapturedMessage>(body)!;
    MailSender.Send(new EmailMessage
    {
        To = m.PatientEmail,
        FirstName = m.PatientName,
        Subject = "Potvrda plaćanja",
        Body = $"Vaša uplata u iznosu {m.Amount} {m.Currency} je uspješno zaprimljena. Termin je potvrđen.",
        Kind = EmailKind.PaymentReceipt
    }, logger);
    return Task.CompletedTask;
});

DeclareAndConsume(QueueNames.PrescriptionIssued, body =>
{
    var m = JsonConvert.DeserializeObject<PrescriptionIssuedMessage>(body)!;
    MailSender.Send(new EmailMessage
    {
        To = m.PatientEmail,
        FirstName = m.PatientName,
        Subject = "Izdat e-recept",
        Body = $"{m.DoctorName} vam je izdao novi e-recept. Možete ga pogledati u aplikaciji eDoktor pod 'Karton → Recepti'.",
        Kind = EmailKind.PrescriptionIssued
    }, logger);
    return Task.CompletedTask;
});

DeclareAndConsume(QueueNames.DoctorCreated, body =>
{
    var m = JsonConvert.DeserializeObject<DoctorCreatedMessage>(body)!;
    MailSender.Send(new EmailMessage
    {
        To = m.Email,
        FirstName = m.FirstName,
        LastName = m.LastName,
        Subject = "Vaš eDoktor nalog je kreiran",
        Body = $"Korisničko ime: {m.Username}\nPrivremena lozinka: {m.TemporaryPassword}\n\nMolimo da promijenite lozinku prilikom prve prijave.",
        Kind = EmailKind.DoctorCredentials
    }, logger);
    return Task.CompletedTask;
});

logger.LogInformation("eDoktor.Worker is running. Press Ctrl+C to stop.");
await Task.Delay(Timeout.Infinite);
