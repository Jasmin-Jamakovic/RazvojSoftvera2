using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Messages;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Auth;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using eDoktor.Services.RabbitMQ;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.Users
{
    public class UserService : IUserService
    {
        private readonly eDoktorDbContext _db;
        private readonly IPasswordHasher _hasher;
        private readonly IJwtTokenService _jwt;
        private readonly IRabbitMQService _rabbit;

        public UserService(eDoktorDbContext db, IPasswordHasher hasher, IJwtTokenService jwt, IRabbitMQService rabbit)
        {
            _db = db;
            _hasher = hasher;
            _jwt = jwt;
            _rabbit = rabbit;
        }

        public async Task<PagedResult<UserResponse>> GetAsync(UserSearchObject search)
        {
            var q = _db.Users.Include(u => u.Role).Include(u => u.City).AsQueryable();
            if (!search.IncludeDeleted) q = q.Where(u => !u.IsDeleted);
            if (!string.IsNullOrWhiteSpace(search.Search))
                q = q.Where(u => u.FirstName.Contains(search.Search) || u.LastName.Contains(search.Search) || u.Username.Contains(search.Search) || u.Email.Contains(search.Search));
            if (!string.IsNullOrWhiteSpace(search.Role))
                q = q.Where(u => u.Role.Name == search.Role);

            search.Normalize();
            int? total = search.IncludeTotalCount ? await q.CountAsync() : null;
            q = q.Skip(search.Page!.Value * search.PageSize!.Value).Take(search.PageSize!.Value);

            var list = await q.ToListAsync();
            return new PagedResult<UserResponse>
            {
                Items = list.Select(u => Map(u)).ToList(),
                TotalCount = total
            };
        }

        public async Task<UserResponse?> GetByIdAsync(int id)
        {
            var u = await _db.Users.Include(x => x.Role).Include(x => x.City).FirstOrDefaultAsync(x => x.Id == id);
            return u == null || u.IsDeleted ? null : Map(u, includeImage: true);
        }

        public async Task<UserResponse> UpdateAsync(int id, UserUpdateRequest req)
        {
            var u = await _db.Users.Include(x => x.Role).Include(x => x.City).FirstOrDefaultAsync(x => x.Id == id)
                ?? throw new UserException("User not found");
            if (req.FirstName != null) u.FirstName = req.FirstName;
            if (req.LastName != null) u.LastName = req.LastName;
            if (req.Email != null) u.Email = req.Email;
            if (req.PhoneNumber != null) u.PhoneNumber = req.PhoneNumber;
            if (req.DateOfBirth.HasValue) u.DateOfBirth = req.DateOfBirth;
            if (req.Gender != null) u.Gender = req.Gender;
            if (req.BloodType != null) u.BloodType = req.BloodType;
            if (req.Allergies != null) u.Allergies = req.Allergies;
            if (req.CityId.HasValue) u.CityId = req.CityId;
            if (req.Latitude.HasValue) u.Latitude = req.Latitude;
            if (req.Longitude.HasValue) u.Longitude = req.Longitude;
            if (req.ReceiveNotifications.HasValue) u.ReceiveNotifications = req.ReceiveNotifications.Value;
            if (req.Image != null)
            {
                if (!ImageValidation.IsValidImage(req.Image))
                    throw new UserException("Slika mora biti validna slika (PNG, JPEG, GIF ili WEBP) i manja od 5 MB.");
                u.Image = req.Image;
            }
            u.LastModifiedAt = System.DateTime.UtcNow;
            await _db.SaveChangesAsync();
            // refresh the City nav so the response carries the correct CityName
            u.City = u.CityId.HasValue ? await _db.Cities.FirstOrDefaultAsync(c => c.Id == u.CityId.Value) : null;
            return Map(u, includeImage: true);
        }

        public async Task<bool> SoftDeleteAsync(int id)
        {
            var u = await _db.Users.FirstOrDefaultAsync(x => x.Id == id);
            if (u == null) return false;
            u.IsDeleted = true;
            await _db.SaveChangesAsync();
            return true;
        }

        public async Task<LoginResponse> LoginAsync(LoginRequest req)
        {
            var u = await _db.Users.Include(x => x.Role).FirstOrDefaultAsync(x => x.Username == req.Username && !x.IsDeleted)
                ?? throw new UserException("Invalid credentials");
            if (!_hasher.Verify(req.Password, u.PasswordHash))
                throw new UserException("Invalid credentials");

            return new LoginResponse { Token = _jwt.GenerateToken(u), User = Map(u, includeImage: true) };
        }

        public async Task<LoginResponse> RegisterPatientAsync(PatientRegisterRequest req)
        {
            if (await _db.Users.AnyAsync(u => u.Username == req.Username))
                throw new UserException("Username already taken");
            if (await _db.Users.AnyAsync(u => u.Email == req.Email))
                throw new UserException("Email already used");

            var patientRole = await _db.Roles.FirstAsync(r => r.Name == Roles.Patient);

            var u = new User
            {
                FirstName = req.FirstName,
                LastName = req.LastName,
                Username = req.Username,
                Email = req.Email,
                PhoneNumber = req.PhoneNumber,
                DateOfBirth = req.DateOfBirth,
                Gender = req.Gender,
                BloodType = req.BloodType,
                Allergies = req.Allergies,
                CityId = req.CityId,
                Latitude = req.Latitude,
                Longitude = req.Longitude,
                PasswordHash = _hasher.Hash(req.Password),
                RoleId = patientRole.Id,
                CreatedAt = System.DateTime.UtcNow
            };
            // User + their empty medical record are created atomically.
            await using (var tx = await _db.Database.BeginTransactionAsync())
            {
                _db.Users.Add(u);
                await _db.SaveChangesAsync();

                _db.MedicalRecords.Add(new MedicalRecord { PatientId = u.Id });
                await _db.SaveChangesAsync();

                await tx.CommitAsync();
            }

            // load the City nav so the returned UserResponse carries CityName
            if (u.CityId.HasValue) u.City = await _db.Cities.FirstOrDefaultAsync(c => c.Id == u.CityId.Value);

            // Welcome email via RabbitMQ
            await _rabbit.PublishEmailAsync(new EmailMessage
            {
                To = u.Email,
                FirstName = u.FirstName,
                LastName = u.LastName,
                Subject = "Dobrodošli u eDoktor",
                Kind = EmailKind.Welcome
            });

            u.Role = patientRole;
            return new LoginResponse { Token = _jwt.GenerateToken(u), User = Map(u, includeImage: true) };
        }

        public async Task<bool> ChangePasswordAsync(int userId, ChangePasswordRequest req)
        {
            var u = await _db.Users.FirstOrDefaultAsync(x => x.Id == userId) ?? throw new UserException("User not found");
            if (!_hasher.Verify(req.OldPassword, u.PasswordHash))
                throw new UserException("Old password is incorrect");
            u.PasswordHash = _hasher.Hash(req.NewPassword);
            u.LastModifiedAt = System.DateTime.UtcNow;
            u.TokenVersion++; // invalidate existing sessions after a password change
            await _db.SaveChangesAsync();
            return true;
        }

        // Server-side logout: bump the token version so all previously issued JWTs stop validating.
        public async Task LogoutAsync(int userId)
        {
            var u = await _db.Users.FirstOrDefaultAsync(x => x.Id == userId) ?? throw new UserException("User not found");
            u.TokenVersion++;
            await _db.SaveChangesAsync();
        }

        private static UserResponse Map(User u, bool includeImage = false) => new()
        {
            Id = u.Id,
            FirstName = u.FirstName,
            LastName = u.LastName,
            Username = u.Username,
            Email = u.Email,
            PhoneNumber = u.PhoneNumber,
            DateOfBirth = u.DateOfBirth,
            Gender = u.Gender,
            BloodType = u.BloodType,
            Allergies = u.Allergies,
            CityId = u.CityId,
            CityName = u.City?.Name,
            Latitude = u.Latitude,
            Longitude = u.Longitude,
            RoleId = u.RoleId,
            Role = u.Role?.Name,
            ReceiveNotifications = u.ReceiveNotifications,
            Image = includeImage ? u.Image : null,
            HasImage = u.Image != null && u.Image.Length > 0,
            CreatedAt = u.CreatedAt
        };
    }
}
