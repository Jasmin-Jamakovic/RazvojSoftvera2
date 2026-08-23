using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Specializations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [Route("api/specializations"), Authorize]
    public class SpecializationsController : BaseCRUDController<SpecializationResponse, SpecializationSearchObject, SpecializationUpsertRequest, SpecializationUpsertRequest>
    {
        public SpecializationsController(ISpecializationService s) : base(s) { }

        [HttpPost, Authorize(Roles = Roles.Admin)]
        public override System.Threading.Tasks.Task<SpecializationResponse> Create(SpecializationUpsertRequest request) => base.Create(request);

        [HttpPut("{id}"), Authorize(Roles = Roles.Admin)]
        public override System.Threading.Tasks.Task<SpecializationResponse> Update(int id, SpecializationUpsertRequest request) => base.Update(id, request);

        [HttpDelete("{id}"), Authorize(Roles = Roles.Admin)]
        public override System.Threading.Tasks.Task<bool> Delete(int id) => base.Delete(id);
    }
}
