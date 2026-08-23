using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;

namespace eDoktor.Services.Cities
{
    public interface ICityService : ICRUDService<CityResponse, CitySearchObject, CityUpsertRequest, CityUpsertRequest> { }
}
