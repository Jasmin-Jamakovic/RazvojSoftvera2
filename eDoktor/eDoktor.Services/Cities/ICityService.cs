using System.Collections.Generic;
using System.Threading.Tasks;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;

namespace eDoktor.Services.Cities
{
    public interface ICityService : ICRUDService<CityResponse, CitySearchObject, CityUpsertRequest, CityUpsertRequest>
    {
        /// Id + name of every active (not deleted) city, sorted by name. Public: used by registration.
        Task<List<CityLookupResponse>> GetActiveLookupAsync();
    }
}
