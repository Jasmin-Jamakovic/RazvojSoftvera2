using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Clinics;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [Route("api/clinics"), Authorize]
    public class ClinicsController : BaseCRUDController<ClinicResponse, ClinicSearchObject, ClinicUpsertRequest, ClinicUpsertRequest>
    {
        public ClinicsController(IClinicService s) : base(s) { }

        [HttpPost, Authorize(Roles = Roles.Admin)]
        public override System.Threading.Tasks.Task<ClinicResponse> Create(ClinicUpsertRequest request) => base.Create(request);

        [HttpPut("{id}"), Authorize(Roles = Roles.Admin)]
        public override System.Threading.Tasks.Task<ClinicResponse> Update(int id, ClinicUpsertRequest request) => base.Update(id, request);

        [HttpDelete("{id}"), Authorize(Roles = Roles.Admin)]
        public override System.Threading.Tasks.Task<bool> Delete(int id) => base.Delete(id);
    }
}
