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
        /// Admin refund; returns the payment's new status (Refunded, or RefundPending while PayPal finishes it).
        Task<string> RefundAsync(string captureId, string? reason);
        Task<bool> HandleWebhookAsync(IDictionary<string, string> headers, string rawBody);

        /// Cancels unpaid bookings whose payment deadline has passed (after checking PayPal for a late payment).
        Task<int> ExpireOverdueAppointmentsAsync();

        /// Marks refunds that PayPal has finished since they were requested as Refunded.
        Task<int> SettlePendingRefundsAsync();
    }
}
