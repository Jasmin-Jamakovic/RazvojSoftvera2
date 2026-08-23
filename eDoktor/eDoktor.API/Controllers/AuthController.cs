using eDoktor.Model;
using System.Threading.Tasks;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Services.Auth;
using eDoktor.Services.Users;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [ApiController]
    [Route("api/auth")]
    public class AuthController : ControllerBase
    {
        private readonly IUserService _users;
        private readonly ICurrentUserService _current;
        public AuthController(IUserService users, ICurrentUserService current) { _users = users; _current = current; }

        [HttpPost("login"), AllowAnonymous]
        public Task<LoginResponse> Login(LoginRequest req) => _users.LoginAsync(req);

        [HttpPost("register"), AllowAnonymous]
        public Task<LoginResponse> Register(PatientRegisterRequest req) => _users.RegisterPatientAsync(req);

        [HttpGet("me"), Authorize]
        public async Task<UserResponse?> Me()
        {
            var id = await _current.GetUserIdAsync();
            return id.HasValue ? await _users.GetByIdAsync(id.Value) : null;
        }

        [HttpPost("change-password"), Authorize]
        public async Task<IActionResult> ChangePassword(ChangePasswordRequest req)
        {
            var id = await _current.GetUserIdAsync();
            if (!id.HasValue) return Unauthorized();
            await _users.ChangePasswordAsync(id.Value, req);
            return Ok();
        }

        // Server-side logout: revokes the caller's currently issued token(s).
        [HttpPost("logout"), Authorize]
        public async Task<IActionResult> Logout()
        {
            var id = await _current.GetUserIdAsync();
            if (!id.HasValue) return Unauthorized();
            await _users.LogoutAsync(id.Value);
            return Ok();
        }
    }
}
