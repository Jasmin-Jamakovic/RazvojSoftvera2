using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;

namespace eDoktor.Services.Countries
{
    public interface ICountryService : ICRUDService<CountryResponse, CountrySearchObject, CountryUpsertRequest, CountryUpsertRequest> { }
}
