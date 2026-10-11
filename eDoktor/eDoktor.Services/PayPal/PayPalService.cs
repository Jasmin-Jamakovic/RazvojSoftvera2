using System;
using System.Collections.Generic;
using System.Globalization;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Threading.Tasks;
using eDoktor.Model;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace eDoktor.Services.PayPal
{
    public class PayPalOptions
    {
        public string ClientId { get; set; } = string.Empty;
        public string ClientSecret { get; set; } = string.Empty;
        public string BaseUrl { get; set; } = string.Empty;
        public string Currency { get; set; } = string.Empty;
        public string WebhookId { get; set; } = string.Empty;
        // Where PayPal redirects after the payer approves / cancels. The mobile WebView intercepts these
        // URLs (they are never actually loaded), so any https URL the app recognises works.
        public string ReturnUrl { get; set; } = string.Empty;
        public string CancelUrl { get; set; } = string.Empty;
    }

    // Pure PayPal HTTP gateway — no database access, no dynamic typing.
    public class PayPalService : IPayPalService
    {
        private readonly HttpClient _http;
        private readonly PayPalOptions _opts;
        private readonly ILogger<PayPalService> _logger;
        private string? _accessToken;
        private DateTime _tokenExpiry = DateTime.MinValue;

        public PayPalService(HttpClient http, PayPalOptions opts, ILogger<PayPalService> logger)
        {
            _http = http;
            _opts = opts;
            _logger = logger;
            _http.BaseAddress = new Uri(_opts.BaseUrl);
        }

        // PayPal's error details go to the log (for reproducing the problem), not to the client.
        private UserException Failure(string operation, HttpResponseMessage resp, string body)
        {
            _logger.LogError("PayPal {Operation} failed: {Status} {Body}", operation, (int)resp.StatusCode, body);
            return new UserException("PayPal trenutno nije dostupan. Pokušajte ponovo kasnije.");
        }

        private async Task<string> GetAccessTokenAsync()
        {
            if (string.IsNullOrWhiteSpace(_opts.ClientId) || string.IsNullOrWhiteSpace(_opts.ClientSecret))
                throw new UserException("Plaćanje nije podešeno (PayPal__ClientId / PayPal__ClientSecret u .env).");

            if (_accessToken != null && DateTime.UtcNow < _tokenExpiry) return _accessToken;

            using var req = new HttpRequestMessage(HttpMethod.Post, "/v1/oauth2/token");
            req.Headers.Authorization = new AuthenticationHeaderValue("Basic",
                Convert.ToBase64String(Encoding.UTF8.GetBytes($"{_opts.ClientId}:{_opts.ClientSecret}")));
            req.Content = new StringContent("grant_type=client_credentials", Encoding.UTF8, "application/x-www-form-urlencoded");

            var resp = await _http.SendAsync(req);
            var body = await resp.Content.ReadAsStringAsync();
            if (!resp.IsSuccessStatusCode)
                throw Failure("authenticate", resp, body);

            var token = JObject.Parse(body);
            _accessToken = (string?)token["access_token"];
            var seconds = (int?)token["expires_in"] ?? 3000;
            _tokenExpiry = DateTime.UtcNow.AddSeconds(seconds - 60);
            return _accessToken!;
        }

        public async Task<PayPalOrderResult> CreateOrderAsync(decimal amount, string currency, string referenceId)
        {
            var token = await GetAccessTokenAsync();
            using var req = new HttpRequestMessage(HttpMethod.Post, "/v2/checkout/orders");
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

            if (string.IsNullOrWhiteSpace(_opts.ReturnUrl) || string.IsNullOrWhiteSpace(_opts.CancelUrl))
                throw new UserException("Plaćanje nije podešeno (PayPal__ReturnUrl / PayPal__CancelUrl).");

            var orderBody = new
            {
                intent = "CAPTURE",
                purchase_units = new[]
                {
                    new
                    {
                        reference_id = referenceId,
                        amount = new { currency_code = currency, value = amount.ToString("F2", CultureInfo.InvariantCulture) }
                    }
                },
                application_context = new
                {
                    brand_name = "eDoktor",
                    shipping_preference = "NO_SHIPPING",
                    user_action = "PAY_NOW",
                    return_url = _opts.ReturnUrl,
                    cancel_url = _opts.CancelUrl
                }
            };
            req.Content = new StringContent(JsonConvert.SerializeObject(orderBody), Encoding.UTF8, "application/json");

            var resp = await _http.SendAsync(req);
            var body = await resp.Content.ReadAsStringAsync();
            if (!resp.IsSuccessStatusCode)
                throw Failure("create order", resp, body);

            var data = JObject.Parse(body);
            var orderId = (string?)data["id"] ?? throw new UserException("PayPal nije vratio broj narudžbe. Pokušajte ponovo.");
            string? approveUrl = null;
            foreach (var l in data["links"] ?? new JArray())
            {
                var rel = (string?)l["rel"];
                if (rel == "approve" || rel == "payer-action") { approveUrl = (string?)l["href"]; break; }
            }

            return new PayPalOrderResult(orderId, approveUrl);
        }

        public async Task<PayPalCaptureResult> CaptureOrderAsync(string orderId)
        {
            var token = await GetAccessTokenAsync();
            using var req = new HttpRequestMessage(HttpMethod.Post, $"/v2/checkout/orders/{orderId}/capture");
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            req.Content = new StringContent("{}", Encoding.UTF8, "application/json");

            var resp = await _http.SendAsync(req);
            var body = await resp.Content.ReadAsStringAsync();
            if (!resp.IsSuccessStatusCode)
                throw Failure("capture", resp, body);

            var data = JObject.Parse(body);
            var capture = data["purchase_units"]?[0]?["payments"]?["captures"]?[0]
                ?? throw new UserException("PayPal nije potvrdio naplatu. Pokušajte ponovo.");
            var captureId = (string?)capture["id"] ?? throw new UserException("PayPal nije vratio broj naplate. Pokušajte ponovo.");
            var status = (string?)capture["status"] ?? string.Empty;
            var value = decimal.TryParse((string?)capture["amount"]?["value"], NumberStyles.Number, CultureInfo.InvariantCulture, out var v) ? v : 0m;
            var currency = (string?)capture["amount"]?["currency_code"] ?? string.Empty;

            return new PayPalCaptureResult(captureId, status, value, currency);
        }

        public async Task<bool> VerifyWebhookAsync(IDictionary<string, string> headers, string rawBody)
        {
            // Without a configured webhook id we cannot prove the call came from PayPal — reject.
            if (string.IsNullOrWhiteSpace(_opts.WebhookId)) return false;

            string? Get(string key) => headers.TryGetValue(key, out var v) ? v : null;
            var transmissionId = Get("paypal-transmission-id");
            var transmissionTime = Get("paypal-transmission-time");
            var transmissionSig = Get("paypal-transmission-sig");
            var certUrl = Get("paypal-cert-url");
            var authAlgo = Get("paypal-auth-algo");
            if (transmissionId is null || transmissionTime is null || transmissionSig is null
                || certUrl is null || authAlgo is null)
                return false;

            var token = await GetAccessTokenAsync();
            using var req = new HttpRequestMessage(HttpMethod.Post, "/v1/notifications/verify-webhook-signature");
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

            var payload = "{"
                + $"\"auth_algo\":{JsonConvert.SerializeObject(authAlgo)},"
                + $"\"cert_url\":{JsonConvert.SerializeObject(certUrl)},"
                + $"\"transmission_id\":{JsonConvert.SerializeObject(transmissionId)},"
                + $"\"transmission_sig\":{JsonConvert.SerializeObject(transmissionSig)},"
                + $"\"transmission_time\":{JsonConvert.SerializeObject(transmissionTime)},"
                + $"\"webhook_id\":{JsonConvert.SerializeObject(_opts.WebhookId)},"
                + $"\"webhook_event\":{rawBody}"
                + "}";
            req.Content = new StringContent(payload, Encoding.UTF8, "application/json");

            var resp = await _http.SendAsync(req);
            if (!resp.IsSuccessStatusCode) return false;
            var body = await resp.Content.ReadAsStringAsync();
            var data = JObject.Parse(body);
            return (string?)data["verification_status"] == "SUCCESS";
        }

        public async Task<bool> RefundAsync(string captureId, decimal? amount = null, string? reason = null)
        {
            var token = await GetAccessTokenAsync();
            using var req = new HttpRequestMessage(HttpMethod.Post, $"/v2/payments/captures/{captureId}/refund");
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

            object payload = amount.HasValue
                ? new { amount = new { value = amount.Value.ToString("F2", CultureInfo.InvariantCulture), currency_code = _opts.Currency }, note_to_payer = reason }
                : new { note_to_payer = reason };
            req.Content = new StringContent(JsonConvert.SerializeObject(payload), Encoding.UTF8, "application/json");

            var resp = await _http.SendAsync(req);
            if (!resp.IsSuccessStatusCode)
                _logger.LogError("PayPal refund of capture {CaptureId} failed: {Status} {Body}",
                    captureId, (int)resp.StatusCode, await resp.Content.ReadAsStringAsync());
            return resp.IsSuccessStatusCode;
        }
    }
}
