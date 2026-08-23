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
        public CitiesController(ICityService s) : base(s) { }

        [HttpPost, Authorize(Roles = Roles.Admin)]
        public override System.Threading.Tasks.Task<CityResponse> Create(CityUpsertRequest request) => base.Create(request);

        [HttpPut("{id}"), Authorize(Roles = Roles.Admin)]
        public override System.Threading.Tasks.Task<CityResponse> Update(int id, CityUpsertRequest request) => base.Update(id, request);

        [HttpDelete("{id}"), Authorize(Roles = Roles.Admin)]
        public override System.Threading.Tasks.Task<bool> Delete(int id) => base.Delete(id);
    }
}
