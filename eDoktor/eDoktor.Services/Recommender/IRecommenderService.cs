using System.Collections.Generic;
using System.Threading.Tasks;
using eDoktor.Model.Responses;

namespace eDoktor.Services.Recommender
{
    public interface IRecommenderService
    {
        Task<List<DoctorResponse>> GetRecommendedAsync(int patientId, int n = 10);
        Task InvalidateAsync(int patientId);
    }
}
