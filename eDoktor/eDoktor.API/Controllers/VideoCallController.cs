using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
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
        private readonly IConsultationChatService _chat;
        private readonly ICurrentUserService _current;
        public VideoCallController(IVideoCallService svc, IConsultationChatService chat, ICurrentUserService current)
        { _svc = svc; _chat = chat; _current = current; }

        [HttpPost("{appointmentId}/room")]
        public async Task<IActionResult> Room(int appointmentId)
        {
            var uid = await _current.GetUserIdAsync() ?? throw new UserException("Niste prijavljeni.");
            var (roomId, joinUrl) = await _svc.GetOrCreateRoomAsync(appointmentId, uid);
            return Ok(new { roomId, joinUrl });
        }

        [HttpGet("{appointmentId}/messages")]
        public Task<PagedResult<ConsultationMessageResponse>> Messages(int appointmentId, [FromQuery] BaseSearchObject s)
            => _chat.GetAsync(appointmentId, s);

        [HttpPost("{appointmentId}/messages")]
        public Task<ConsultationMessageResponse> Send(int appointmentId, ConsultationMessageRequest req)
            => _chat.SendAsync(appointmentId, req);

        [HttpGet("{appointmentId}/messages/{messageId}/image")]
        public async Task<IActionResult> MessageImage(int appointmentId, int messageId)
        {
            var (bytes, contentType) = await _chat.GetImageAsync(appointmentId, messageId);
            return File(bytes, contentType);
        }
    }
}
