using System.Threading.Tasks;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;

namespace eDoktor.Services.VideoCalls
{
    public interface IConsultationChatService
    {
        Task<PagedResult<ConsultationMessageResponse>> GetAsync(int appointmentId, BaseSearchObject search);
        Task<ConsultationMessageResponse> SendAsync(int appointmentId, ConsultationMessageRequest req);
        Task<(byte[] Bytes, string ContentType)> GetImageAsync(int appointmentId, int messageId);
    }
}
