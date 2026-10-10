using System.IO;
using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Payments;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [ApiController, Route("api/payments"), Authorize]
    public class PaymentsController : ControllerBase
    {
        private readonly IPaymentService _payments;

        public PaymentsController(IPaymentService payments) => _payments = payments;

        [HttpGet]
        public Task<PagedResult<PaymentResponse>> Get([FromQuery] PaymentSearchObject s)
            => _payments.GetAsync(s);

        // Admins get totals for all payments, patients for their own (scoping is done in the service).
        [HttpGet("summary")]
        public Task<PaymentSummaryResponse> Summary([FromQuery] PaymentSearchObject s)
            => _payments.GetSummaryAsync(s);

        [HttpPost("paypal/orders")]
        public Task<PayPalOrderResponse> CreateOrder(PayPalCreateOrderRequest req)
            => _payments.CreateOrderAsync(req);

        [HttpPost("paypal/orders/{orderId}/capture")]
        public Task<PaymentResponse> Capture(string orderId)
            => _payments.CaptureAsync(orderId);

        [HttpPost("paypal/captures/{captureId}/refund"), Authorize(Roles = Roles.Admin)]
        public async Task<IActionResult> Refund(string captureId, PayPalRefundRequest req)
            => await _payments.RefundAsync(captureId, req.Reason) ? Ok() : BadRequest("Refund failed");

        [HttpPost("paypal/webhook"), AllowAnonymous]
        public async Task<IActionResult> Webhook()
        {
            using var reader = new StreamReader(Request.Body);
            var body = await reader.ReadToEndAsync();
            var headers = Request.Headers.ToDictionary(h => h.Key.ToLowerInvariant(), h => h.Value.ToString());
            return await _payments.HandleWebhookAsync(headers, body) ? Ok() : Unauthorized();
        }
    }
}
