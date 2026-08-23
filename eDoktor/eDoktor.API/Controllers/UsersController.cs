using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Auth;
using eDoktor.Services.Users;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [ApiController, Route("api/users"), Authorize]
    public class UsersController : ControllerBase
    {
        private readonly IUserService _users;
        private readonly ICurrentUserService _current;
        public UsersController(IUserService users, ICurrentUserService current) { _users = users; _current = current; }

        [HttpGet, Authorize(Roles = Roles.Admin)]
        public Task<PagedResult<UserResponse>> Get([FromQuery] UserSearchObject s) => _users.GetAsync(s ?? new());

        [HttpGet("{id}"), Authorize(Roles = Roles.Admin)]
        public Task<UserResponse?> GetById(int id) => _users.GetByIdAsync(id);

        // Serves the user photo separately (no blobs in list responses, spec §8.2). Owner or admin only.
        [HttpGet("{id}/photo")]
        public async Task<IActionResult> Photo(int id)
        {
            var me = await _current.GetUserIdAsync();
            var role = await _current.GetUserRoleAsync();
            if (role != Roles.Admin && me != id)
                throw new ForbiddenException("You can only view your own photo.");

            var u = await _users.GetByIdAsync(id);
            if (u?.Image == null || u.Image.Length == 0) return NotFound();
            return File(u.Image, ImageValidation.DetectContentType(u.Image) ?? "application/octet-stream");
        }

        [HttpPut("{id}")]
        public async Task<UserResponse> Update(int id, UserUpdateRequest req)
        {
            var me = await _current.GetUserIdAsync();
            var role = await _current.GetUserRoleAsync();
            if (role != Roles.Admin && me != id)
                throw new ForbiddenException("You can only edit your own profile.");
            return await _users.UpdateAsync(id, req);
        }

        [HttpDelete("{id}"), Authorize(Roles = Roles.Admin)]
        public Task<bool> Delete(int id) => _users.SoftDeleteAsync(id);
    }
}
