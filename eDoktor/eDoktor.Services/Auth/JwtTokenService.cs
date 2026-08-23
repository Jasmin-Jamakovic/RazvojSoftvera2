using eDoktor.Model;
using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using eDoktor.Services.Database.Entities;
using Microsoft.IdentityModel.Tokens;

namespace eDoktor.Services.Auth
{
    public class JwtTokenOptions
    {
        public string Issuer { get; set; } = "eDoktor";
        public string Audience { get; set; } = "eDoktor";
        public string Key { get; set; } = "change-me-please-this-must-be-at-least-32-bytes-long!!!";
        public int ExpiryMinutes { get; set; } = 1440;
    }

    public class JwtTokenService : IJwtTokenService
    {
        private readonly JwtTokenOptions _opts;

        public JwtTokenService(JwtTokenOptions opts)
        {
            _opts = opts;
        }

        public string GenerateToken(User user)
        {
            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new(ClaimTypes.Name, user.Username),
                new(ClaimTypes.Email, user.Email),
                new(ClaimTypes.Role, user.Role?.Name ?? Roles.Patient),
                new("tv", user.TokenVersion.ToString()),
                new("firstName", user.FirstName ?? string.Empty),
                new("lastName", user.LastName ?? string.Empty)
            };

            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_opts.Key));
            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var jwt = new JwtSecurityToken(
                issuer: _opts.Issuer,
                audience: _opts.Audience,
                claims: claims,
                expires: DateTime.UtcNow.AddMinutes(_opts.ExpiryMinutes),
                signingCredentials: creds);

            return new JwtSecurityTokenHandler().WriteToken(jwt);
        }
    }
}
