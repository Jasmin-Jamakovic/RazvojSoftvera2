using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Countries;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [Route("api/countries"), Authorize]
    public class CountriesController : BaseCRUDController<CountryResponse, CountrySearchObject, CountryUpsertRequest, CountryUpsertRequest>
    {
        public CountriesController(ICountryService s) : base(s) { }

        [HttpPost, Authorize(Roles = Roles.Admin)]
        public override System.Threading.Tasks.Task<CountryResponse> Create(CountryUpsertRequest request) => base.Create(request);

        [HttpPut("{id}"), Authorize(Roles = Roles.Admin)]
        public override System.Threading.Tasks.Task<CountryResponse> Update(int id, CountryUpsertRequest request) => base.Update(id, request);

        [HttpDelete("{id}"), Authorize(Roles = Roles.Admin)]
        public override System.Threading.Tasks.Task<bool> Delete(int id) => base.Delete(id);
    }
}
