using System.Collections.Generic;
using System.Threading.Tasks;

namespace eDoktor.Services.PayPal
{
    // Result of creating a PayPal order (raw gateway data; persistence is the caller's job).
    public record PayPalOrderResult(string OrderId, string? ApproveUrl);

    // Result of capturing a PayPal order.
    public record PayPalCaptureResult(string CaptureId, string Status, decimal Amount, string Currency);

    // Current state of an order: its status (CREATED, APPROVED, COMPLETED, ...) and its capture, if one was made.
    public record PayPalOrderInfo(string Status, PayPalCaptureResult? Capture);

    // PayPal's answer to a refund request. Status is PayPal's refund status: COMPLETED means the money is back
    // with the payer; PENDING means PayPal accepted the refund but has not finished it yet.
    public record PayPalRefundResult(string Status)
    {
        public bool IsCompleted => Status == "COMPLETED";
        public bool IsPending => Status == "PENDING";
    }

    // Thin PayPal REST gateway: talks HTTP to PayPal only. It performs NO database work,
    // so it can safely be a transient typed HttpClient (no captive DbContext).
    public interface IPayPalService
    {
        Task<PayPalOrderResult> CreateOrderAsync(decimal amount, string currency, string referenceId);
        Task<PayPalCaptureResult> CaptureOrderAsync(string orderId);
        /// Refunds a capture in full (the amount PayPal actually captured). Returns null when PayPal rejects the request.
        Task<PayPalRefundResult?> RefundAsync(string captureId, string? reason = null);

        /// Reads an order; null when PayPal no longer knows it (e.g. an abandoned order that expired).
        Task<PayPalOrderInfo?> GetOrderAsync(string orderId);

        /// Reads a capture's status (COMPLETED, REFUNDED, PARTIALLY_REFUNDED, ...).
        Task<string> GetCaptureStatusAsync(string captureId);

        /// <summary>
        /// Verifies a PayPal webhook against the configured WebhookId using PayPal's
        /// verify-webhook-signature API. Returns false if it cannot be verified.
        /// </summary>
        Task<bool> VerifyWebhookAsync(IDictionary<string, string> headers, string rawBody);
    }
}
