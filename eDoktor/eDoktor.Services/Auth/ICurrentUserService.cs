namespace eDoktor.Services.Auth
{
    public interface ICurrentUserService
    {
        Task<int?> GetUserIdAsync(CancellationToken cancellationToken = default);
        Task<string?> GetUserRoleAsync(CancellationToken cancellationToken = default);
    }
} 