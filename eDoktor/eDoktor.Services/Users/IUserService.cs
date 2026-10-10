using System.Threading.Tasks;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;

namespace eDoktor.Services.Users
{
    public interface IUserService
    {
        Task<PagedResult<UserResponse>> GetAsync(UserSearchObject search);
        Task<UserResponse?> GetByIdAsync(int id);
        Task<UserResponse> UpdateAsync(int id, UserUpdateRequest req);
        Task<bool> SoftDeleteAsync(int id);

        Task<LoginResponse> LoginAsync(LoginRequest req);
        Task<LoginResponse> RegisterPatientAsync(PatientRegisterRequest req);
        Task<bool> ChangePasswordAsync(int userId, ChangePasswordRequest req);
        Task ForgotPasswordAsync(ForgotPasswordRequest req);
        Task ResetPasswordAsync(ResetPasswordRequest req);
        Task LogoutAsync(int userId);
    }
}
