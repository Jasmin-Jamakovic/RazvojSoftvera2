using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Messages;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.AppointmentStateMachine;
using eDoktor.Services.Auth;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using eDoktor.Services.Notifications;
using eDoktor.Services.PayPal;
using eDoktor.Services.RabbitMQ;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using System.Globalization;
using Microsoft.Extensions.Logging;
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
        private readonly IServiceProvider _sp;
        private readonly IMapper _mapper;
        private readonly PayPalOptions _paypalOptions;
        private readonly ILogger<PaymentService> _logger;

        public PaymentService(eDoktorDbContext db, IPayPalService paypal, IRabbitMQService rabbit,
            INotificationService notifications, ICurrentUserService current,
            IServiceProvider sp, IMapper mapper, PayPalOptions paypalOptions, ILogger<PaymentService> logger)
        {
            _logger = logger;
            _paypalOptions = paypalOptions;
            _db = db;
            _paypal = paypal;
            _rabbit = rabbit;
            _notifications = notifications;
            _current = current;
            _sp = sp;
            _mapper = mapper;
        }

        public async Task<PagedResult<PaymentResponse>> GetAsync(PaymentSearchObject search)
        {
            search.Normalize();
            var q = await FilterAsync(search);

            // In a period, the list shows every payment with activity in it: captured, refunded,
            // or (for unfinished orders) created in that period.
            if (search.From.HasValue || search.To.HasValue)
            {
                var from = search.From ?? DateTime.MinValue;
                var to = search.To ?? DateTime.MaxValue;
                q = q.Where(x =>
                    (x.Payment.CapturedAt >= from && x.Payment.CapturedAt < to) ||
                    (x.Payment.RefundedAt >= from && x.Payment.RefundedAt < to) ||
                    (x.Payment.CapturedAt == null && x.Payment.CreatedAt >= from && x.Payment.CreatedAt < to));
            }

            int? total = search.IncludeTotalCount ? await q.CountAsync() : null;

            var notice = PaymentRules.RefundCancellationNotice.TotalHours;
            var items = await q
                .OrderByDescending(x => x.Payment.CreatedAt)
                .Skip(search.Page!.Value * search.PageSize!.Value)
                .Take(search.PageSize!.Value)
                .Select(x => new PaymentResponse
                {
                    Id = x.Payment.Id,
                    AppointmentId = x.Payment.AppointmentId,
                    OrderId = x.Payment.OrderId,
                    CaptureId = x.Payment.CaptureId,
                    Amount = x.Payment.Amount,
                    Currency = x.Payment.Currency,
                    Status = x.Payment.Status,
                    CreatedAt = x.Payment.CreatedAt,
                    CapturedAt = x.Payment.CapturedAt,
                    RefundedAt = x.Payment.RefundedAt,
                    PatientName = x.Appointment.Patient.FirstName + " " + x.Appointment.Patient.LastName,
                    DoctorName = x.Appointment.Doctor.User.FirstName + " " + x.Appointment.Doctor.User.LastName,
                    AppointmentStartUtc = x.Appointment.TimeSlot.StartUtc,
                    AppointmentStatus = x.Appointment.StateMachine.Replace("AppointmentState", string.Empty),
                    // Same condition as PaymentRules.RefundAllowed, written so the database can evaluate it.
                    CanRefund = x.Payment.Status == PaymentStatus.Captured && x.Payment.CaptureId != null
                        && x.Appointment.StateMachine == nameof(CancelledAppointmentState)
                        && x.Appointment.CancelledAt != null
                        && (x.Appointment.CancelledById != x.Appointment.PatientId
                            || x.Appointment.CancelledAt <= x.Appointment.TimeSlot.StartUtc.AddHours(-notice))
                })
                .ToListAsync();

            return new PagedResult<PaymentResponse> { Items = items, TotalCount = total };
        }

        // Gross collections are counted on the day the money was captured and refunds on the day the money went
        // back, so a payment captured in one month and refunded in the next stays in the first month's gross and
        // reduces only the second month's net. Net = gross - refunds of the same period.
        public async Task<PaymentSummaryResponse> GetSummaryAsync(PaymentSearchObject search)
        {
            var q = await FilterAsync(search);
            var from = search.From ?? DateTime.MinValue;
            var to = search.To ?? DateTime.MaxValue;

            var captured = await q
                .Where(x => x.Payment.CapturedAt != null && x.Payment.CapturedAt >= from && x.Payment.CapturedAt < to)
                .Select(x => x.Payment.Amount).ToListAsync();
            var refunded = await q
                .Where(x => x.Payment.Status == PaymentStatus.Refunded && x.Payment.RefundedAt >= from && x.Payment.RefundedAt < to)
                .Select(x => x.Payment.Amount).ToListAsync();
            var pending = await q.CountAsync(x => x.Payment.Status == PaymentStatus.Created);

            return new PaymentSummaryResponse
            {
                From = search.From,
                To = search.To,
                TotalCaptured = captured.Sum(),
                TotalRefunded = refunded.Sum(),
                NetRevenue = captured.Sum() - refunded.Sum(),
                CapturedCount = captured.Count,
                RefundedCount = refunded.Count,
                PendingCount = pending
            };
        }

        private async Task<IQueryable<PaymentRow>> FilterAsync(PaymentSearchObject s)
        {
            // Patients only ever see their own transactions; doctors have no access to payment data.
            var role = await _current.GetUserRoleAsync();
            if (role == Roles.Patient)
                s.PatientId = await _current.GetUserIdAsync();
            else if (role != Roles.Admin)
                throw new ForbiddenException("Nemate pristup uplatama.");

            var q = from p in _db.PayPalPayments
                    join a in _db.Appointments on p.AppointmentId equals a.Id
                    select new PaymentRow { Payment = p, Appointment = a };

            if (s.PatientId.HasValue) q = q.Where(x => x.Appointment.PatientId == s.PatientId.Value);
            if (s.DoctorId.HasValue) q = q.Where(x => x.Appointment.DoctorId == s.DoctorId.Value);
            if (!string.IsNullOrWhiteSpace(s.Status)) q = q.Where(x => x.Payment.Status == s.Status);
            if (!string.IsNullOrWhiteSpace(s.Search))
            {
                var term = s.Search.Trim();
                q = q.Where(x =>
                    (x.Appointment.Patient.FirstName + " " + x.Appointment.Patient.LastName).Contains(term) ||
                    (x.Appointment.Doctor.User.FirstName + " " + x.Appointment.Doctor.User.LastName).Contains(term));
            }
            return q;
        }

        private class PaymentRow
        {
            public PayPalPayment Payment { get; set; } = null!;
            public Appointment Appointment { get; set; } = null!;
        }

        public async Task<PayPalOrderResponse> CreateOrderAsync(PayPalCreateOrderRequest req)
        {
            var appt = await _db.Appointments.FirstOrDefaultAsync(a => a.Id == req.AppointmentId)
                ?? throw new NotFoundException("Termin nije pronađen.");

            await EnsureOwnerOrAdminAsync(appt.PatientId, "You can only pay for your own appointment.");
            if (appt.StateMachine != nameof(PendingAppointmentState))
                throw new UserException("Plaćanje je moguće samo za termin koji čeka plaćanje.");
            var slotStart = await _db.TimeSlots.Where(t => t.Id == appt.TimeSlotId).Select(t => t.StartUtc).FirstAsync();
            if (DateTime.UtcNow >= PaymentRules.PaymentDeadline(appt.CreatedAt, slotStart))
                throw new UserException("Rok za plaćanje ovog termina je istekao. Termin će biti otkazan, a slot oslobođen.");

            // Double-charge guard: a settled payment blocks a new one. An unfinished order (patient left the
            // PayPal page) is retired so the patient can retry; it can no longer be captured.
            var previous = await _db.PayPalPayments.Where(p => p.AppointmentId == appt.Id).ToListAsync();
            if (previous.Any(p => p.Status == PaymentStatus.Captured || p.Status == PaymentStatus.Refunded))
                throw new UserException("Termin je već plaćen.");
            foreach (var p in previous.Where(p => p.Status == PaymentStatus.Created))
                p.Status = PaymentStatus.Cancelled;

            // Amount comes from the server-side catalog (appointment price), never from the client.
            var order = await _paypal.CreateOrderAsync(appt.Price, _paypalOptions.Currency, $"appointment-{appt.Id}");

            // One save: the new order plus the retired ones above.
            _db.PayPalPayments.Add(new PayPalPayment
            {
                AppointmentId = appt.Id,
                OrderId = order.OrderId,
                Amount = appt.Price,
                Currency = _paypalOptions.Currency,
                Status = PaymentStatus.Created
            });
            await _db.SaveChangesAsync();

            return new PayPalOrderResponse
            {
                OrderId = order.OrderId,
                ApproveUrl = order.ApproveUrl,
                AppointmentId = appt.Id,
                ReturnUrl = _paypalOptions.ReturnUrl,
                CancelUrl = _paypalOptions.CancelUrl
            };
        }

        public async Task<PaymentResponse> CaptureAsync(string orderId)
        {
            var payment = await _db.PayPalPayments.FirstOrDefaultAsync(p => p.OrderId == orderId)
                ?? throw new NotFoundException("Plaćanje nije pronađeno.");

            var appt = await _db.Appointments.Include(a => a.Patient).Include(a => a.Doctor).ThenInclude(d => d.User)
                .FirstOrDefaultAsync(a => a.Id == payment.AppointmentId);
            await EnsureOwnerOrAdminAsync(appt?.PatientId ?? 0, "You can only capture your own payment.");

            // Idempotency: if already captured, don't call PayPal again or re-run side effects.
            if (payment.Status == PaymentStatus.Captured)
                return _mapper.Map<PaymentResponse>(payment);
            if (payment.Status != PaymentStatus.Created)
                throw new UserException("Ova narudžba više nije važeća. Pokrenite plaćanje ponovo.");
            // Never take money for an appointment that was cancelled (or otherwise moved on) while the
            // patient was on the PayPal page: the order is retired and PayPal is not called.
            if (appt == null || appt.StateMachine != nameof(PendingAppointmentState))
            {
                payment.Status = PaymentStatus.Cancelled;
                await _db.SaveChangesAsync();
                throw new UserException("Termin više nije moguće platiti jer je otkazan.");
            }

            var capture = await _paypal.CaptureOrderAsync(orderId);
            // Only a completed capture of exactly the charged amount confirms the appointment.
            if (capture.Status != "COMPLETED")
                throw new UserException("PayPal nije potvrdio naplatu. Pokušajte ponovo.");
            if (capture.Amount != payment.Amount || capture.Currency != payment.Currency)
                throw new UserException("Naplaćeni iznos se ne podudara sa cijenom termina.");

            await ApplyCaptureAsync(payment, capture);
            return _mapper.Map<PaymentResponse>(payment);
        }

        /// Records a completed PayPal capture for an open order: marks the payment Captured, confirms the
        /// appointment through the state machine, notifies patient and doctor, and queues the receipt email.
        /// Shared by the app's capture call, the PayPal webhook and the deadline check, so whichever of them
        /// learns about the payment first completes the same flow, and the others find it already done.
        private async Task ApplyCaptureAsync(PayPalPayment payment, PayPalCaptureResult capture)
        {
            var appt = await _db.Appointments.Include(a => a.Patient).Include(a => a.Doctor).ThenInclude(d => d.User)
                .FirstAsync(a => a.Id == payment.AppointmentId);

            await using (var tx = await _db.Database.BeginTransactionAsync())
            {
                payment.CaptureId = capture.CaptureId;
                payment.Status = PaymentStatus.Captured;
                payment.CapturedAt = DateTime.UtcNow;
                await _db.SaveChangesAsync();

                // Confirm through the state machine (Pending -> Confirmed), not a direct column write.
                // The state joins this transaction.
                if (appt.StateMachine == nameof(PendingAppointmentState))
                    await _sp.GetRequiredService<InitialAppointmentState>().GetState(appt.StateMachine).ConfirmAsync(appt.Id);

                await _notifications.SendAsync(appt.PatientId, "Plaćanje uspješno",
                    $"Vaša uplata od {payment.Amount:0.00} {payment.Currency} za termin je uspješno obrađena. Termin je potvrđen.",
                    "payment");
                await _notifications.SendAsync(appt.Doctor.UserId, "Termin je plaćen",
                    $"Pacijent {appt.Patient.FirstName} {appt.Patient.LastName} je platio termin ({payment.Amount:0.00} {payment.Currency}). Termin je potvrđen.",
                    "payment");
                await tx.CommitAsync();
            }

            // The receipt email is queued only after the payment is committed.
            await _rabbit.PublishAsync(QueueNames.PaymentCaptured, new PaymentCapturedMessage
            {
                PaymentId = payment.Id,
                AppointmentId = appt.Id,
                PatientId = appt.PatientId,
                PatientEmail = appt.Patient.Email,
                PatientName = $"{appt.Patient.FirstName} {appt.Patient.LastName}",
                Amount = payment.Amount,
                Currency = payment.Currency
            });
        }

        public async Task<string> RefundAsync(string captureId, string? reason)
        {
            var payment = await _db.PayPalPayments.FirstOrDefaultAsync(p => p.CaptureId == captureId)
                ?? throw new NotFoundException("Uplata nije pronađena.");

            // Only a captured payment can be refunded; this also stops the same payment being refunded twice.
            if (payment.Status != PaymentStatus.Captured)
                throw new UserException(payment.Status == PaymentStatus.RefundPending
                    ? "Povrat ove uplate je već u obradi kod PayPala."
                    : "Povrat sredstava je moguć samo za naplaćene uplate.");

            // The server checks the refund condition itself instead of trusting the button the desktop shows.
            var appt = await _db.Appointments.Include(a => a.TimeSlot).FirstAsync(a => a.Id == payment.AppointmentId);
            if (appt.StateMachine != nameof(CancelledAppointmentState))
                throw new UserException("Povrat je moguć samo za otkazan termin. Termin prvo otkažite.");
            if (!PaymentRules.RefundAllowed(appt))
                throw new UserException("Pacijent je otkazao termin manje od 24 sata prije početka, pa nema pravo na povrat.");

            // PayPal refunds the full amount it actually captured (no amount is sent).
            var refund = await _paypal.RefundAsync(captureId, reason);
            if (refund == null || !(refund.IsCompleted || refund.IsPending))
                throw new UserException("PayPal nije prihvatio povrat. Pokušajte ponovo kasnije.");

            if (refund.IsCompleted)
            {
                payment.Status = PaymentStatus.Refunded;
                payment.RefundedAt = DateTime.UtcNow;
                await _db.SaveChangesAsync();
                await _notifications.SendAsync(appt.PatientId, "Povrat novca",
                    $"Iznos od {payment.Amount:0.00} {payment.Currency} je vraćen na vaš PayPal račun.", "payment");
            }
            else
            {
                // Accepted but not finished: shown as "in progress" until PayPal confirms the money is back.
                payment.Status = PaymentStatus.RefundPending;
                await _db.SaveChangesAsync();
            }
            return payment.Status;
        }

        public async Task<bool> HandleWebhookAsync(IDictionary<string, string> headers, string rawBody)
        {
            // Verify the call genuinely came from PayPal before trusting/acting on it.
            if (!await _paypal.VerifyWebhookAsync(headers, rawBody))
                return false;

            var evt = JObject.Parse(rawBody);
            var resource = evt["resource"];
            switch ((string?)evt["event_type"])
            {
                case "PAYMENT.CAPTURE.COMPLETED":
                    await OnCaptureCompletedAsync(resource);
                    break;
                case "PAYMENT.CAPTURE.REFUNDED":
                    await OnCaptureRefundedAsync(resource);
                    break;
            }
            return true;
        }

        // The capture belongs to one of our orders (resource.supplementary_data.related_ids.order_id). Only an
        // order that is still open moves forward; an already captured, refunded or refund-pending payment is
        // left exactly as it is, so a late or repeated notification can never undo a refund.
        private async Task OnCaptureCompletedAsync(JToken? resource)
        {
            var captureId = (string?)resource?["id"];
            var orderId = (string?)resource?["supplementary_data"]?["related_ids"]?["order_id"];
            if (string.IsNullOrEmpty(captureId)) return;

            var payment = await _db.PayPalPayments.FirstOrDefaultAsync(p => p.CaptureId == captureId)
                ?? (string.IsNullOrEmpty(orderId) ? null : await _db.PayPalPayments.FirstOrDefaultAsync(p => p.OrderId == orderId));
            if (payment == null || payment.Status != PaymentStatus.Created) return;

            var amount = decimal.TryParse((string?)resource?["amount"]?["value"], NumberStyles.Number, CultureInfo.InvariantCulture, out var v) ? v : 0m;
            var currency = (string?)resource?["amount"]?["currency_code"] ?? string.Empty;
            if (amount != payment.Amount || currency != payment.Currency) return;

            // The appointment may have been cancelled meanwhile; then there is nothing to confirm.
            var stillPending = await _db.Appointments.AnyAsync(a => a.Id == payment.AppointmentId && a.StateMachine == nameof(PendingAppointmentState));
            if (!stillPending) return;

            await ApplyCaptureAsync(payment, new PayPalCaptureResult(captureId, "COMPLETED", amount, currency));
        }

        // PayPal finished a refund: the resource is the refund; its "up" link points to the refunded capture.
        private async Task OnCaptureRefundedAsync(JToken? resource)
        {
            if ((string?)resource?["status"] != "COMPLETED") return;
            string? captureId = null;
            foreach (var link in resource?["links"] ?? new JArray())
                if ((string?)link["rel"] == "up")
                    captureId = ((string?)link["href"])?.TrimEnd('/').Split('/').Last();
            if (string.IsNullOrEmpty(captureId)) return;

            var payment = await _db.PayPalPayments.FirstOrDefaultAsync(p => p.CaptureId == captureId);
            if (payment != null) await MarkRefundCompletedAsync(payment);
        }

        private async Task MarkRefundCompletedAsync(PayPalPayment payment)
        {
            if (payment.Status != PaymentStatus.RefundPending && payment.Status != PaymentStatus.Captured) return;
            payment.Status = PaymentStatus.Refunded;
            payment.RefundedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
            var patientId = await _db.Appointments.Where(a => a.Id == payment.AppointmentId).Select(a => a.PatientId).FirstAsync();
            await _notifications.SendAsync(patientId, "Povrat novca",
                $"Iznos od {payment.Amount:0.00} {payment.Currency} je vraćen na vaš PayPal račun.", "payment");
        }

        // ------------------------------------------------------------------ background maintenance

        public async Task<int> ExpireOverdueAppointmentsAsync()
        {
            var now = DateTime.UtcNow;
            var bookedBefore = now - PaymentRules.PaymentWindow;
            var overdue = await _db.Appointments
                .Where(a => a.StateMachine == nameof(PendingAppointmentState) && a.Price > 0
                    && !a.Payments.Any(p => p.Status == PaymentStatus.Captured || p.Status == PaymentStatus.Refunded || p.Status == PaymentStatus.RefundPending)
                    && (a.CreatedAt <= bookedBefore || a.TimeSlot.StartUtc <= now))
                .Select(a => a.Id)
                .ToListAsync();

            var expired = 0;
            foreach (var id in overdue)
            {
                try
                {
                // Before closing the booking, ask PayPal how its open order ended: if the patient did pay,
                // the payment is recorded and the appointment confirmed instead of cancelled.
                var openOrders = await _db.PayPalPayments
                    .Where(p => p.AppointmentId == id && p.Status == PaymentStatus.Created)
                    .OrderByDescending(p => p.CreatedAt).ToListAsync();
                var paid = false;
                foreach (var payment in openOrders)
                {
                    var order = await _paypal.GetOrderAsync(payment.OrderId);
                    if (order?.Capture is { Status: "COMPLETED" } c && c.Amount == payment.Amount && c.Currency == payment.Currency)
                    {
                        await ApplyCaptureAsync(payment, c);
                        paid = true;
                        break;
                    }
                }
                if (paid) continue;

                await _sp.GetRequiredService<PendingAppointmentState>().ExpireUnpaidAsync(id);
                expired++;
                }
                catch (Exception ex)
                {
                    // E.g. PayPal unreachable: the outcome of the payment is unknown, so the booking is not
                    // cancelled now; it is checked again on the next run.
                    _logger.LogWarning(ex, "Could not close overdue unpaid appointment {AppointmentId}; will retry.", id);
                }
            }
            return expired;
        }

        public async Task<int> SettlePendingRefundsAsync()
        {
            var pending = await _db.PayPalPayments
                .Where(p => p.Status == PaymentStatus.RefundPending && p.CaptureId != null).ToListAsync();
            var settled = 0;
            foreach (var payment in pending)
            {
                try
                {
                    if (await _paypal.GetCaptureStatusAsync(payment.CaptureId!) != "REFUNDED") continue;
                    await MarkRefundCompletedAsync(payment);
                    settled++;
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Could not check pending refund of payment {PaymentId}; will retry.", payment.Id);
                }
            }
            return settled;
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
