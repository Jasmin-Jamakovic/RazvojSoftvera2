using System.Threading.Tasks;

namespace eDoktor.Services.VideoCalls
{
    public interface IVideoCallService
    {
        Task<string> GetOrCreateRoomAsync(int appointmentId, int userId);
    }
}
