using System.Collections.Generic;
using System.Threading.Tasks;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;

namespace eDoktor.Services.Payments
{
    public interface IPaymentService
    {
        Task<PayPalOrderResponse> CreateOrderAsync(PayPalCreateOrderRequest req);
        Task<PaymentResponse> CaptureAsync(string orderId);
        Task<bool> RefundAsync(string captureId, decimal? amount, string? reason);
        Task<bool> HandleWebhookAsync(IDictionary<string, string> headers, string rawBody);
    }
}
