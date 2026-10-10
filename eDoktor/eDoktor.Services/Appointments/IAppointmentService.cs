using System.Threading.Tasks;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;

namespace eDoktor.Services.Appointments
{
    public interface IAppointmentService
    {
        Task<PagedResult<AppointmentResponse>> GetAsync(AppointmentSearchObject search);
        Task<AppointmentResponse> GetByIdAsync(int id);
        Task<AppointmentResponse> CreateAsync(AppointmentCreateRequest req, int patientId);
        Task<AppointmentResponse> ConfirmAsync(int id);
        Task<AppointmentResponse> CompleteAsync(int id);
        Task<AppointmentResponse> CancelAsync(int id, AppointmentStatusChangeRequest req);
        Task<AppointmentResponse> RescheduleAsync(int id, AppointmentRescheduleRequest req);
    }
}
