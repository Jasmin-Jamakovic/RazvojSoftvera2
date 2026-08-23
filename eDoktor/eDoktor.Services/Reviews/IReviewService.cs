using System.Threading.Tasks;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;

namespace eDoktor.Services.Reviews
{
    public interface IReviewService
    {
        Task<PagedResult<ReviewResponse>> GetAsync(ReviewSearchObject search);
        Task<ReviewResponse> CreateAsync(ReviewUpsertRequest req, int patientId);
        Task<bool> DeleteAsync(int id);
    }
}
