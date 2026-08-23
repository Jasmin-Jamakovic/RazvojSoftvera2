using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace eDoktor.Services.SignalR
{
    [Authorize]
    public class NotificationHub : Hub
    {
        public override Task OnConnectedAsync()
        {
            var userId = Context.User?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            if (!string.IsNullOrEmpty(userId))
            {
                return Groups.AddToGroupAsync(Context.ConnectionId, $"user-{userId}");
            }
            return base.OnConnectedAsync();
        }
    }
}
