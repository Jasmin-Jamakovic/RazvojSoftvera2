using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class BaseCRUDController<T, TSearch, TInsert, TUpdate> : BaseController<T, TSearch> where T : class where TSearch : BaseSearchObject, new() where TInsert : class where TUpdate : class
    {
        protected readonly ICRUDService<T, TSearch, TInsert, TUpdate> _crudService;

        public BaseCRUDController(ICRUDService<T, TSearch, TInsert, TUpdate> service) : base(service)
        {
            _crudService = service;
        }

        [HttpPost, Authorize(Roles = Roles.Admin)]
        public virtual async Task<T> Create([FromBody] TInsert request){
            return await _crudService.CreateAsync(request);
        }

        [HttpPut("{id}"), Authorize(Roles = Roles.Admin)]
        public virtual async Task<T> Update(int id, [FromBody] TUpdate request){
            return await _crudService.UpdateAsync(id, request);
        }

        [HttpDelete("{id}"), Authorize(Roles = Roles.Admin)]
        public virtual async Task<bool> Delete(int id){
            return await _crudService.DeleteAsync(id);
        }

        [HttpDelete("{id}/soft"), Authorize(Roles = Roles.Admin)]
        public virtual async Task<IActionResult> SoftDelete(int id)
        {
            var result = await _crudService.SoftDeleteAsync(id);
            if (!result)
                return NotFound();

            return Ok(new { message = "Entity soft deleted successfully" });
        }

        [HttpPost("{id}/restore"), Authorize(Roles = Roles.Admin)]
        public virtual async Task<IActionResult> Restore(int id)
        {
            var result = await _crudService.RestoreAsync(id);
            if (!result)
                return NotFound();

            return Ok(new { message = "Entity restored successfully" });
        }
    }
}