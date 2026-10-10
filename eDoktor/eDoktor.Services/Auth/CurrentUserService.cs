using Microsoft.AspNetCore.Http;
using System.Security.Claims;

namespace eDoktor.Services.Auth
{
    public class CurrentUserService : ICurrentUserService
    {
        private readonly IHttpContextAccessor _httpContextAccessor;

        public CurrentUserService(IHttpContextAccessor httpContextAccessor)
        {
            _httpContextAccessor = httpContextAccessor;
        }

        public Task<int?> GetUserIdAsync(CancellationToken cancellationToken = default)
        {
            var userIdClaim = _httpContextAccessor.HttpContext?.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out int userId))
            {
                return Task.FromResult<int?>(null);
            }

            return Task.FromResult<int?>(userId);
        }

        public Task<string?> GetUserRoleAsync(CancellationToken cancellationToken = default)
        {
            var userRole = _httpContextAccessor.HttpContext?.User?.FindFirst(ClaimTypes.Role)?.Value;
            return Task.FromResult(userRole);
        }
    }
} 