using System.Collections.Generic;
using System.Threading.Tasks;

namespace eDoktor.Services.PayPal
{
    // Result of creating a PayPal order (raw gateway data; persistence is the caller's job).
    public record PayPalOrderResult(string OrderId, string? ApproveUrl);

    // Result of capturing a PayPal order.
    public record PayPalCaptureResult(string CaptureId);

    // Thin PayPal REST gateway: talks HTTP to PayPal only. It performs NO database work,
    // so it can safely be a transient typed HttpClient (no captive DbContext).
    public interface IPayPalService
    {
        Task<PayPalOrderResult> CreateOrderAsync(decimal amount, string currency, string referenceId);
        Task<PayPalCaptureResult> CaptureOrderAsync(string orderId);
        Task<bool> RefundAsync(string captureId, decimal? amount = null, string? reason = null);

        /// <summary>
        /// Verifies a PayPal webhook against the configured WebhookId using PayPal's
        /// verify-webhook-signature API. Returns false if it cannot be verified.
        /// </summary>
        Task<bool> VerifyWebhookAsync(IDictionary<string, string> headers, string rawBody);
    }
}
