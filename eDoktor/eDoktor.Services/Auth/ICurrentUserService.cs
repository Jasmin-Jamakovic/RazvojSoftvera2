using eDoktor.Services.Database.Entities;

namespace eDoktor.Services.Auth
{
    public interface ICurrentUserService
    {
        Task<int?> GetUserIdAsync(CancellationToken cancellationToken = default);
        Task<string?> GetUserNameAsync(CancellationToken cancellationToken = default);
        Task<string?> GetUserRoleAsync(CancellationToken cancellationToken = default);
        Task<bool> IsAdminAsync(CancellationToken cancellationToken = default);
        Task<User?> GetCurrentUserAsync(CancellationToken cancellationToken = default);
    }
} 