using System.Collections.Generic;
using System.Threading.Tasks;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;

namespace eDoktor.Services.TimeSlots
{
    public interface ITimeSlotService
    {
        Task<List<TimeSlotResponse>> GetAsync(TimeSlotSearchObject search);
        Task<int> GenerateAsync(TimeSlotGenerateRequest req);
        Task DeleteAsync(int id);
    }
}
