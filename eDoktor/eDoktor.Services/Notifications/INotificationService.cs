using System.Threading.Tasks;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;

namespace eDoktor.Services.Notifications
{
    public interface INotificationService
    {
        Task<PagedResult<NotificationResponse>> GetAsync(NotificationSearchObject search);
        Task<NotificationResponse> SendAsync(int userId, string title, string body, string type = "general");
        Task<bool> MarkAsReadAsync(int id, int userId);
        Task<int> MarkAllAsReadAsync(int userId);
    }
}
