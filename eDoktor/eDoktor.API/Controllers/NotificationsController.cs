using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Auth;
using eDoktor.Services.Notifications;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [ApiController, Route("api/notifications"), Authorize]
    public class NotificationsController : ControllerBase
    {
        private readonly INotificationService _svc;
        private readonly ICurrentUserService _current;
        public NotificationsController(INotificationService svc, ICurrentUserService current) { _svc = svc; _current = current; }

        [HttpGet]
        public async Task<PagedResult<NotificationResponse>> Get([FromQuery] NotificationSearchObject s)
        {
            var uid = await _current.GetUserIdAsync() ?? throw new UserException("Niste prijavljeni.");
            s ??= new();
            s.UserId = uid;
            return await _svc.GetAsync(s);
        }

        [HttpPost("{id}/read")]
        public async Task<IActionResult> MarkRead(int id)
        {
            var uid = await _current.GetUserIdAsync() ?? throw new UserException("Niste prijavljeni.");
            var ok = await _svc.MarkAsReadAsync(id, uid);
            return ok ? Ok() : NotFound();
        }

        [HttpPost("read-all")]
        public async Task<IActionResult> MarkAllRead()
        {
            var uid = await _current.GetUserIdAsync() ?? throw new UserException("Niste prijavljeni.");
            var n = await _svc.MarkAllAsReadAsync(uid);
            return Ok(new { marked = n });
        }
    }
}
