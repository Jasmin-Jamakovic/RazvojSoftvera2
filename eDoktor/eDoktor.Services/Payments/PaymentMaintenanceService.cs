using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace eDoktor.Services.Payments
{
    // Runs every minute:
    //  - closes bookings that were not paid by their payment deadline (PaymentRules.PaymentDeadline), so their
    //    slot becomes free again; PayPal is asked first whether the patient did pay after all;
    //  - marks refunds PayPal accepted as "pending" as Refunded once PayPal reports the money returned.
    public class PaymentMaintenanceService : BackgroundService
    {
        private static readonly TimeSpan CheckInterval = TimeSpan.FromMinutes(1);
        private readonly IServiceScopeFactory _scopes;
        private readonly ILogger<PaymentMaintenanceService> _logger;

        public PaymentMaintenanceService(IServiceScopeFactory scopes, ILogger<PaymentMaintenanceService> logger)
        {
            _scopes = scopes;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            using var timer = new PeriodicTimer(CheckInterval);
            do
            {
                try
                {
                    // A fresh scope (and DbContext) per run, like a separate request.
                    using var scope = _scopes.CreateScope();
                    var payments = scope.ServiceProvider.GetRequiredService<IPaymentService>();
                    var expired = await payments.ExpireOverdueAppointmentsAsync();
                    if (expired > 0) _logger.LogInformation("Cancelled {Count} unpaid appointment(s) after the payment deadline.", expired);
                    var settled = await payments.SettlePendingRefundsAsync();
                    if (settled > 0) _logger.LogInformation("{Count} pending refund(s) confirmed by PayPal.", settled);
                }
                catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
                {
                    _logger.LogError(ex, "Payment maintenance run failed.");
                }
            } while (await timer.WaitForNextTickAsync(stoppingToken));
        }
    }
}
