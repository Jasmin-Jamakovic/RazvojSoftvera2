using System.Threading.Tasks;
using eDoktor.Model.Messages;

namespace eDoktor.Services.RabbitMQ
{
    public interface IRabbitMQService
    {
        // Messages are published after the data is committed, so a broker failure must not fail the request:
        // it is logged and reported as false.
        Task<bool> PublishAsync<T>(string queue, T message);
        Task<bool> PublishEmailAsync(EmailMessage email);
    }
}
