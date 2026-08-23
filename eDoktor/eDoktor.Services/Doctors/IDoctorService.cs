using System.Threading.Tasks;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;

namespace eDoktor.Services.Doctors
{
    public interface IDoctorService
    {
        Task<PagedResult<DoctorResponse>> GetAsync(DoctorSearchObject search);
        Task<DoctorResponse?> GetByIdAsync(int id);
        Task<DoctorResponse> CreateAsync(DoctorUpsertRequest req);
        Task<DoctorResponse> UpdateAsync(int id, DoctorUpsertRequest req);
        Task<bool> SoftDeleteAsync(int id);
    }
}
