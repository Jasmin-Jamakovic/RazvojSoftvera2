using System.Collections.Generic;
using System.Threading.Tasks;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;

namespace eDoktor.Services.Payments
{
    public interface IPaymentService
    {
        Task<PagedResult<PaymentResponse>> GetAsync(PaymentSearchObject search);
        Task<PaymentSummaryResponse> GetSummaryAsync(PaymentSearchObject search);
        Task<PayPalOrderResponse> CreateOrderAsync(PayPalCreateOrderRequest req);
        Task<PaymentResponse> CaptureAsync(string orderId);
        Task<bool> RefundAsync(string captureId, string? reason);
        Task<bool> HandleWebhookAsync(IDictionary<string, string> headers, string rawBody);
    }
}
