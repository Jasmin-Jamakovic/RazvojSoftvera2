using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Messages;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Services.Appointments;
using eDoktor.Services.AppointmentStateMachine;
using eDoktor.Services.Auth;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using eDoktor.Services.Notifications;
using eDoktor.Services.PayPal;
using eDoktor.Services.RabbitMQ;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Newtonsoft.Json.Linq;

namespace eDoktor.Services.Payments
{
    // Owns all payment persistence and business logic (kept out of the controller and out of the
    // PayPal HTTP gateway). Appointment state changes go through the state machine, never direct writes.
    public class PaymentService : IPaymentService
    {
        private readonly eDoktorDbContext _db;
        private readonly IPayPalService _paypal;
        private readonly IRabbitMQService _rabbit;
        private readonly INotificationService _notifications;
        private readonly ICurrentUserService _current;
        private readonly IAppointmentService _appointments;
        private readonly IMapper _mapper;

        public PaymentService(eDoktorDbContext db, IPayPalService paypal, IRabbitMQService rabbit,
            INotificationService notifications, ICurrentUserService current,
            IAppointmentService appointments, IMapper mapper)
        {
            _db = db;
            _paypal = paypal;
            _rabbit = rabbit;
            _notifications = notifications;
            _current = current;
            _appointments = appointments;
            _mapper = mapper;
        }

        public async Task<PayPalOrderResponse> CreateOrderAsync(PayPalCreateOrderRequest req)
        {
            var appt = await _db.Appointments.FirstOrDefaultAsync(a => a.Id == req.AppointmentId)
                ?? throw new NotFoundException("Appointment not found");

            await EnsureOwnerOrAdminAsync(appt.PatientId, "You can only pay for your own appointment.");

            // Double-charge guard: never start a new order when one is already settled/in-flight.
            var existing = await _db.PayPalPayments
                .Where(p => p.AppointmentId == appt.Id)
                .OrderByDescending(p => p.Id)
                .FirstOrDefaultAsync();
            if (existing != null && (existing.Status == PaymentStatus.Captured || existing.Status == PaymentStatus.Created))
                throw new UserException("A payment for this appointment already exists.");

            // Amount comes from the server-side catalog (appointment price), never from the client.
            var order = await _paypal.CreateOrderAsync(appt.Price, "EUR", $"appointment-{appt.Id}");

            // Two writes (insert payment, link to appointment) committed atomically.
            await using var tx = await _db.Database.BeginTransactionAsync();
            var payment = new PayPalPayment
            {
                AppointmentId = appt.Id,
                OrderId = order.OrderId,
                Amount = appt.Price,
                Currency = "EUR",
                Status = PaymentStatus.Created
            };
            _db.PayPalPayments.Add(payment);
            await _db.SaveChangesAsync();
            appt.PayPalPaymentId = payment.Id;
            await _db.SaveChangesAsync();
            await tx.CommitAsync();

            return new PayPalOrderResponse { OrderId = order.OrderId, ApproveUrl = order.ApproveUrl, AppointmentId = appt.Id };
        }

        public async Task<PaymentResponse> CaptureAsync(string orderId)
        {
            var payment = await _db.PayPalPayments.FirstOrDefaultAsync(p => p.OrderId == orderId)
                ?? throw new NotFoundException("Payment not found for order " + orderId);

            var appt = await _db.Appointments.Include(a => a.Patient)
                .FirstOrDefaultAsync(a => a.Id == payment.AppointmentId);
            await EnsureOwnerOrAdminAsync(appt?.PatientId ?? 0, "You can only capture your own payment.");

            // Idempotency: if already captured, don't call PayPal again or re-run side effects.
            if (payment.Status == PaymentStatus.Captured)
                return _mapper.Map<PaymentResponse>(payment);

            var capture = await _paypal.CaptureOrderAsync(orderId);

            await using var tx = await _db.Database.BeginTransactionAsync();
            payment.CaptureId = capture.CaptureId;
            payment.Status = PaymentStatus.Captured;
            payment.CapturedAt = System.DateTime.UtcNow;
            await _db.SaveChangesAsync();

            if (appt != null)
            {
                // Confirm through the state machine (Pending -> Confirmed), not a direct column write.
                if (appt.StateMachine == nameof(PendingAppointmentState))
                    await _appointments.ConfirmAsync(appt.Id);

                await _rabbit.PublishAsync(QueueNames.PaymentCaptured, new PaymentCapturedMessage
                {
                    PaymentId = payment.Id,
                    AppointmentId = appt.Id,
                    PatientId = appt.PatientId,
                    PatientEmail = appt.Patient!.Email,
                    PatientName = $"{appt.Patient.FirstName} {appt.Patient.LastName}",
                    Amount = payment.Amount,
                    Currency = payment.Currency
                });

                await _notifications.SendAsync(appt.PatientId, "Plaćanje uspješno",
                    $"Vaša uplata od {payment.Amount:0.00} {payment.Currency} za termin je uspješno obrađena. Termin je potvrđen.",
                    "payment");
            }
            await tx.CommitAsync();

            return _mapper.Map<PaymentResponse>(payment);
        }

        public async Task<bool> RefundAsync(string captureId, decimal? amount, string? reason)
        {
            var payment = await _db.PayPalPayments.FirstOrDefaultAsync(p => p.CaptureId == captureId);

            // Refund the amount actually charged (from our record), not a value supplied by the client.
            var refundAmount = payment?.Amount ?? amount;
            var ok = await _paypal.RefundAsync(captureId, refundAmount, reason);
            if (!ok) return false;

            if (payment != null)
            {
                payment.Status = PaymentStatus.Refunded;
                payment.RefundedAt = System.DateTime.UtcNow;
                await _db.SaveChangesAsync();
            }
            return true;
        }

        public async Task<bool> HandleWebhookAsync(IDictionary<string, string> headers, string rawBody)
        {
            // Verify the call genuinely came from PayPal before trusting/acting on it.
            if (!await _paypal.VerifyWebhookAsync(headers, rawBody))
                return false;

            var evt = JObject.Parse(rawBody);
            if ((string?)evt["event_type"] == "PAYMENT.CAPTURE.COMPLETED")
            {
                var captureId = (string?)evt["resource"]?["id"];
                if (!string.IsNullOrEmpty(captureId))
                {
                    var p = await _db.PayPalPayments.FirstOrDefaultAsync(x => x.CaptureId == captureId);
                    if (p != null && p.Status != PaymentStatus.Captured)
                    {
                        p.Status = PaymentStatus.Captured;
                        p.CapturedAt = System.DateTime.UtcNow;
                        await _db.SaveChangesAsync();
                    }
                }
            }
            return true;
        }

        private async Task EnsureOwnerOrAdminAsync(int ownerId, string message)
        {
            var role = await _current.GetUserRoleAsync();
            var uid = await _current.GetUserIdAsync();
            if (role != Roles.Admin && ownerId != uid)
                throw new ForbiddenException(message);
        }
    }
}
