using System.Threading.Tasks;
using eDoktor.Model.Messages;

namespace eDoktor.Services.RabbitMQ
{
    public interface IRabbitMQService
    {
        Task PublishAsync<T>(string queue, T message);
        Task PublishEmailAsync(EmailMessage email);
    }
}
