using System;
using System.Collections.Generic;
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
        // A channel (IModel) is not thread-safe: connecting and publishing happen one at a time.
        private readonly SemaphoreSlim _gate = new(1, 1);
        private readonly HashSet<string> _declaredQueues = new();
        private IConnection? _connection;
        private IModel? _channel;

        public RabbitMQService(ILogger<RabbitMQService> logger)
        {
            _logger = logger;

            string Required(string name) => Environment.GetEnvironmentVariable(name)
                ?? throw new InvalidOperationException($"{name} is not configured (set it in .env).");

            _factory = new ConnectionFactory
            {
                HostName = Required("_rabbitMqHost"),
                UserName = Required("_rabbitMqUser"),
                Password = Required("_rabbitMqPassword"),
                Port = int.Parse(Required("_rabbitMqPort")),
                DispatchConsumersAsync = false,
                RequestedConnectionTimeout = TimeSpan.FromSeconds(5)
            };
        }

        // Lazily open the connection/channel, retrying briefly (1s, 2s) so a broker that is just starting is
        // picked up, while a request never waits long when the broker is down. Caller holds _gate.
        private async Task<IModel> EnsureChannelAsync()
        {
            if (_channel is { IsOpen: true }) return _channel;

            _declaredQueues.Clear();
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
                catch (Exception ex) when (attempt < 3)
                {
                    _logger.LogWarning(ex, "RabbitMQ connect attempt {Attempt} failed; retrying in {Delay}s.",
                        attempt, delay.TotalSeconds);
                    await Task.Delay(delay);
                    delay *= 2;
                }
            }
        }

        public async Task<bool> PublishAsync<T>(string queue, T message)
        {
            var body = Encoding.UTF8.GetBytes(JsonConvert.SerializeObject(message));
            await _gate.WaitAsync();
            try
            {
                var channel = await EnsureChannelAsync();
                // Durable queue (declared once per channel) + persistent message: survives a broker restart.
                if (_declaredQueues.Add(queue))
                    channel.QueueDeclare(queue: queue, durable: true, exclusive: false, autoDelete: false, arguments: null);
                var props = channel.CreateBasicProperties();
                props.Persistent = true;
                channel.BasicPublish(exchange: string.Empty, routingKey: queue, basicProperties: props, body: body);
                return true;
            }
            catch (Exception ex)
            {
                // The broker closes the channel on errors; drop it so the next publish reconnects.
                _logger.LogError(ex, "Publishing to queue '{Queue}' failed; the message was not sent.", queue);
                _declaredQueues.Clear();
                try { _channel?.Dispose(); } catch { /* channel already closed by the broker */ }
                _channel = null;
                return false;
            }
            finally
            {
                _gate.Release();
            }
        }

        public Task<bool> PublishEmailAsync(EmailMessage email) => PublishAsync(QueueNames.Email, email);

        public void Dispose()
        {
            try { _channel?.Close(); _connection?.Close(); }
            catch (Exception ex) { _logger.LogWarning(ex, "Error while closing RabbitMQ connection."); }
        }
    }
}
