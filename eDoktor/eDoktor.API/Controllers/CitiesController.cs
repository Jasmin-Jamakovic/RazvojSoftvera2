using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Cities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [Route("api/cities"), Authorize]
    public class CitiesController : BaseCRUDController<CityResponse, CitySearchObject, CityUpsertRequest, CityUpsertRequest>
    {
        private readonly ICityService _cities;

        public CitiesController(ICityService s) : base(s) { _cities = s; }

        // Registration happens before login, so the city picker needs a list it can read without a token.
        // Only id + name of active cities are exposed here; the full CRUD list stays behind [Authorize].
        [HttpGet("lookup"), AllowAnonymous]
        public System.Threading.Tasks.Task<System.Collections.Generic.List<CityLookupResponse>> Lookup() => _cities.GetActiveLookupAsync();

        [HttpPost, Authorize(Roles = Roles.Admin)]
        public override System.Threading.Tasks.Task<CityResponse> Create(CityUpsertRequest request) => base.Create(request);

        [HttpPut("{id}"), Authorize(Roles = Roles.Admin)]
        public override System.Threading.Tasks.Task<CityResponse> Update(int id, CityUpsertRequest request) => base.Update(id, request);

        [HttpDelete("{id}"), Authorize(Roles = Roles.Admin)]
        public override System.Threading.Tasks.Task<bool> Delete(int id) => base.Delete(id);
    }
}
