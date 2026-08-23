using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.SearchObjects;
using eDoktor.Services;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;
using System.Threading.Tasks;
using eDoktor.Model.Responses;
using Microsoft.AspNetCore.Authorization;

namespace eDoktor.API.Controllers
{
    [ApiController]
    [Route("[controller]")]
    [Authorize]
    public class BaseController<T, TSearch> : ControllerBase where T : class where TSearch : BaseSearchObject, new()
    {
        protected readonly IService<T, TSearch> _service;

        public BaseController(IService<T, TSearch> service)
        {
            _service = service;
        }

        [HttpGet("")]
        public virtual async Task<PagedResult<T>> Get([FromQuery] TSearch? search = null)
        {
            return await _service.GetAsync(search ?? new TSearch());
        }

        [HttpGet("{id}")]
        public virtual async Task<T?> GetById(int id)
        {
            return await _service.GetByIdAsync(id);
        }

        // [HttpPost]
        // public virtual async Task<ActionResult<T>> Create([FromBody] T request)
        // {
        //     var result = await _service.CreateAsync(request);
        //     return Ok(result);
        // }

        // [HttpPut("{id}")]
        // public virtual async Task<ActionResult<T>> Update(int id, [FromBody] T request)
        // {
        //     var result = await _service.UpdateAsync(id, request);
        //     if (result == null)
        //         return NotFound();
        //     return Ok(result);
        // }

        // [HttpDelete("{id}")]
        // public virtual async Task<ActionResult<bool>> Delete(int id)
        // {
        //     var result = await _service.DeleteAsync(id);
        //     if (!result)
        //         return NotFound();
        //     return Ok(result);
        // }
    }
} 