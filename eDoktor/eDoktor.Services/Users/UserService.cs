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
        private readonly ICurrentUserService _current;

        public UserService(eDoktorDbContext db, IPasswordHasher hasher, IJwtTokenService jwt, IRabbitMQService rabbit, ICurrentUserService current)
        {
            _db = db;
            _hasher = hasher;
            _jwt = jwt;
            _rabbit = rabbit;
            _current = current;
        }

        // A user may read/change only their own profile; an admin may do so for anyone.
        private async Task EnsureSelfOrAdminAsync(int userId, string message)
        {
            if (await _current.GetUserRoleAsync() == Roles.Admin) return;
            if (await _current.GetUserIdAsync() != userId) throw new ForbiddenException(message);
        }

        public async Task<(byte[] Bytes, string ContentType)?> GetPhotoAsync(int id)
        {
            await EnsureSelfOrAdminAsync(id, "Možete vidjeti samo vlastitu fotografiju.");
            var image = await _db.Users.Where(u => u.Id == id && !u.IsDeleted).Select(u => u.Image).FirstOrDefaultAsync();
            if (image == null || image.Length == 0) return null;
            return (image, ImageValidation.DetectContentType(image) ?? "application/octet-stream");
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
            await EnsureSelfOrAdminAsync(id, "Možete uređivati samo vlastiti profil.");
            var u = await _db.Users.Include(x => x.Role).Include(x => x.City).FirstOrDefaultAsync(x => x.Id == id)
                ?? throw new NotFoundException("Korisnik nije pronađen.");
            if (req.CityId.HasValue && !await _db.Cities.AnyAsync(c => c.Id == req.CityId.Value))
                throw new UserException("Odabrani grad ne postoji.");
            if (req.FirstName != null) u.FirstName = req.FirstName.Trim();
            if (req.LastName != null) u.LastName = req.LastName.Trim();
            if (req.Email != null)
            {
                var email = req.Email.Trim();
                if (await _db.Users.AnyAsync(x => x.Email == email && x.Id != id))
                    throw new UserException("Ova email adresa je već registrovana na drugom računu.");
                u.Email = email;
            }
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
            var today = System.DateTime.UtcNow.Date;
            if (req.DateOfBirth!.Value.Date > today)
                throw new UserException("Datum rođenja ne može biti u budućnosti.");
            if (req.DateOfBirth.Value.Date < today.AddYears(-120))
                throw new UserException("Unesite ispravan datum rođenja.");

            if (await _db.Users.AnyAsync(u => u.Username == req.Username))
                throw new UserException("Korisničko ime je zauzeto. Odaberite drugo.");
            if (await _db.Users.AnyAsync(u => u.Email == req.Email))
                throw new UserException("Ova email adresa je već registrovana.");

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

        private const int ResetCodeMinutes = 15;
        private const int ResetCodeMaxAttempts = 5;

        // Always completes silently so the response never reveals whether an account exists for the email.
        public async Task ForgotPasswordAsync(ForgotPasswordRequest req)
        {
            var email = req.Email.Trim();
            var u = await _db.Users.FirstOrDefaultAsync(x => x.Email == email && !x.IsDeleted);
            if (u == null) return;

            var now = System.DateTime.UtcNow;
            var active = await _db.PasswordResetCodes.Where(c => c.UserId == u.Id && c.UsedAt == null && c.ExpiresAt > now).ToListAsync();
            // Throttle: at most one new code per minute.
            if (active.Any(c => c.CreatedAt > now.AddMinutes(-1))) return;

            // Only the newest code is valid; older ones are retired.
            foreach (var old in active) old.UsedAt = now;

            var code = System.Security.Cryptography.RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
            _db.PasswordResetCodes.Add(new PasswordResetCode
            {
                UserId = u.Id,
                CodeHash = _hasher.Hash(code),
                CreatedAt = now,
                ExpiresAt = now.AddMinutes(ResetCodeMinutes)
            });
            await _db.SaveChangesAsync();

            await _rabbit.PublishEmailAsync(new EmailMessage
            {
                To = u.Email,
                FirstName = u.FirstName,
                LastName = u.LastName,
                Subject = "eDoktor - kod za resetovanje lozinke",
                Body = $"Vaš kod za resetovanje lozinke je {code}. Kod vrijedi {ResetCodeMinutes} minuta. Ako niste zatražili promjenu lozinke, zanemarite ovu poruku.",
                Kind = EmailKind.PasswordReset
            });
        }

        public async Task ResetPasswordAsync(ResetPasswordRequest req)
        {
            const string invalid = "Kod je neispravan ili je istekao. Zatražite novi kod.";
            var email = req.Email.Trim();
            var u = await _db.Users.FirstOrDefaultAsync(x => x.Email == email && !x.IsDeleted)
                ?? throw new UserException(invalid);

            var now = System.DateTime.UtcNow;
            var entry = await _db.PasswordResetCodes
                .Where(c => c.UserId == u.Id && c.UsedAt == null && c.ExpiresAt > now)
                .OrderByDescending(c => c.CreatedAt)
                .FirstOrDefaultAsync()
                ?? throw new UserException(invalid);

            if (!_hasher.Verify(req.Code, entry.CodeHash))
            {
                entry.FailedAttempts++;
                if (entry.FailedAttempts >= ResetCodeMaxAttempts) entry.UsedAt = now;
                await _db.SaveChangesAsync();
                throw new UserException(entry.UsedAt == null
                    ? $"Kod nije ispravan. Preostalo pokušaja: {ResetCodeMaxAttempts - entry.FailedAttempts}."
                    : "Previše neuspješnih pokušaja. Zatražite novi kod.");
            }

            entry.UsedAt = now;
            u.PasswordHash = _hasher.Hash(req.NewPassword);
            u.LastModifiedAt = now;
            u.TokenVersion++; // sign out every existing session
            await _db.SaveChangesAsync();
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
