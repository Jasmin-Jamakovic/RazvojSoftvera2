using System;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using eDoktor.Model.Messages;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using RabbitMQ.Client;

namespace eDoktor.Services.RabbitMQ
{
    public class RabbitMQService : IRabbitMQService, IDisposable
    {
        private readonly ILogger<RabbitMQService> _logger;
        private readonly ConnectionFactory _factory;
        private readonly SemaphoreSlim _gate = new(1, 1);
        private IConnection? _connection;
        private IModel? _channel;

        public RabbitMQService(ILogger<RabbitMQService> logger)
        {
            _logger = logger;

            var hostname = Environment.GetEnvironmentVariable("_rabbitMqHost")
                ?? throw new InvalidOperationException("_rabbitMqHost is not configured.");
            var username = Environment.GetEnvironmentVariable("_rabbitMqUser")
                ?? throw new InvalidOperationException("_rabbitMqUser is not configured.");
            var password = Environment.GetEnvironmentVariable("_rabbitMqPassword")
                ?? throw new InvalidOperationException("_rabbitMqPassword is not configured.");
            var port = int.Parse(Environment.GetEnvironmentVariable("_rabbitMqPort") ?? "5672");

            _factory = new ConnectionFactory
            {
                HostName = hostname,
                UserName = username,
                Password = password,
                Port = port,
                DispatchConsumersAsync = false
            };
        }

        // Lazily open the connection/channel with exponential backoff so the API can boot
        // before the broker is ready without blocking the startup thread (no .Wait()/Thread.Sleep).
        private async Task<IModel> EnsureChannelAsync()
        {
            if (_channel is { IsOpen: true }) return _channel;

            await _gate.WaitAsync();
            try
            {
                if (_channel is { IsOpen: true }) return _channel;

                var delay = TimeSpan.FromSeconds(1);
                for (var attempt = 1; ; attempt++)
                {
                    try
                    {
                        _connection = _factory.CreateConnection();
                        _channel = _connection.CreateModel();
                        _logger.LogInformation("Connected to RabbitMQ at {Host}:{Port}.", _factory.HostName, _factory.Port);
                        return _channel;
                    }
                    catch (Exception ex) when (attempt < 6)
                    {
                        _logger.LogWarning(ex, "RabbitMQ connect attempt {Attempt} failed; retrying in {Delay}s.",
                            attempt, delay.TotalSeconds);
                        await Task.Delay(delay);
                        delay = TimeSpan.FromSeconds(Math.Min(delay.TotalSeconds * 2, 30));
                    }
                }
            }
            finally
            {
                _gate.Release();
            }
        }

        public async Task PublishAsync<T>(string queue, T message)
        {
            var channel = await EnsureChannelAsync();
            channel.QueueDeclare(queue: queue, durable: false, exclusive: false, autoDelete: false, arguments: null);
            var json = JsonConvert.SerializeObject(message);
            var body = Encoding.UTF8.GetBytes(json);
            channel.BasicPublish(exchange: string.Empty, routingKey: queue, basicProperties: null, body: body);
        }

        public Task PublishEmailAsync(EmailMessage email) => PublishAsync(QueueNames.Email, email);

        public void Dispose()
        {
            try { _channel?.Close(); _connection?.Close(); }
            catch (Exception ex) { _logger.LogWarning(ex, "Error while closing RabbitMQ connection."); }
        }
    }
}
