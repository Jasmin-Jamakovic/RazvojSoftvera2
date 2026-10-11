using System.Threading.Tasks;

namespace eDoktor.Services.VideoCalls
{
    public interface IVideoCallService
    {
        Task<(string RoomId, string JoinUrl)> GetOrCreateRoomAsync(int appointmentId, int userId);
    }
}
