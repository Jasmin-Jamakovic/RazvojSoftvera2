using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Services.Auth;
using eDoktor.Services.VideoCalls;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [ApiController, Route("api/video-calls"), Authorize]
    public class VideoCallController : ControllerBase
    {
        private readonly IVideoCallService _svc;
        private readonly ICurrentUserService _current;
        public VideoCallController(IVideoCallService svc, ICurrentUserService current) { _svc = svc; _current = current; }

        [HttpPost("{appointmentId}/room")]
        public async Task<IActionResult> Room(int appointmentId)
        {
            var uid = await _current.GetUserIdAsync() ?? throw new UserException("Not authenticated");
            var roomId = await _svc.GetOrCreateRoomAsync(appointmentId, uid);
            return Ok(new { roomId, joinUrl = $"https://meet.jit.si/{roomId}" });
        }
    }
}
