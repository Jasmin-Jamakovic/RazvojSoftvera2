using eDoktor.Services.Database.Entities;

namespace eDoktor.Services.Auth
{
    public interface IJwtTokenService
    {
        string GenerateToken(User user);
    }
}
