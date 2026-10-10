using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Users;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [ApiController, Route("api/users"), Authorize]
    public class UsersController : ControllerBase
    {
        private readonly IUserService _users;
        public UsersController(IUserService users) { _users = users; }

        [HttpGet, Authorize(Roles = Roles.Admin)]
        public Task<PagedResult<UserResponse>> Get([FromQuery] UserSearchObject s) => _users.GetAsync(s ?? new());

        [HttpGet("{id}"), Authorize(Roles = Roles.Admin)]
        public Task<UserResponse?> GetById(int id) => _users.GetByIdAsync(id);

        // Serves the user photo separately (no blobs in list responses, spec §8.2). Owner or admin only.
        [HttpGet("{id}/photo")]
        public async Task<IActionResult> Photo(int id)
        {
            var photo = await _users.GetPhotoAsync(id);
            return photo == null ? NotFound() : File(photo.Value.Bytes, photo.Value.ContentType);
        }

        // Owner-or-admin is enforced in the service.
        [HttpPut("{id}")]
        public Task<UserResponse> Update(int id, UserUpdateRequest req) => _users.UpdateAsync(id, req);

        [HttpDelete("{id}"), Authorize(Roles = Roles.Admin)]
        public Task<bool> Delete(int id) => _users.SoftDeleteAsync(id);
    }
}
