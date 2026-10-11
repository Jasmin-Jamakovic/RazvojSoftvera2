using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Responses;
using eDoktor.Services.Database;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json.Linq;

namespace eDoktor.Services.Geocoding
{
    public class GeocodingOptions
    {
        // OpenStreetMap Nominatim-compatible search API (from .env, Geocoding__BaseUrl).
        public string BaseUrl { get; set; } = string.Empty;
    }

    public interface IGeocodingService
    {
        Task<List<GeocodingResultResponse>> SearchAsync(string address, int? cityId);
    }

    // Turns an address (+ city) into coordinates so clinic locations are picked, not typed in by hand.
    public class GeocodingService : IGeocodingService
    {
        private const int MaxResults = 5;
        private readonly HttpClient _http;
        private readonly eDoktorDbContext _db;
        private readonly ILogger<GeocodingService> _logger;

        public GeocodingService(HttpClient http, GeocodingOptions opts, eDoktorDbContext db, ILogger<GeocodingService> logger)
        {
            _http = http;
            _db = db;
            _logger = logger;
            _http.BaseAddress = new Uri(opts.BaseUrl.TrimEnd('/') + "/");
            // Nominatim's usage policy requires an identifying User-Agent.
            _http.DefaultRequestHeaders.UserAgent.ParseAdd("eDoktor/1.0 (FIT RS2 seminarski rad)");
        }

        public async Task<List<GeocodingResultResponse>> SearchAsync(string address, int? cityId)
        {
            if (string.IsNullOrWhiteSpace(address) || address.Trim().Length < 3)
                throw new UserException("Unesite adresu (najmanje 3 znaka).");

            var parts = new List<string> { address.Trim() };
            if (cityId.HasValue)
            {
                var city = await _db.Cities.Where(c => c.Id == cityId.Value).Select(c => new { c.Name, c.Country }).FirstOrDefaultAsync()
                    ?? throw new NotFoundException("Odabrani grad ne postoji.");
                parts.Add(city.Name);
                if (!string.IsNullOrWhiteSpace(city.Country)) parts.Add(city.Country);
            }
            var query = Uri.EscapeDataString(string.Join(", ", parts));

            using var resp = await _http.GetAsync($"search?format=jsonv2&limit={MaxResults}&q={query}");
            var body = await resp.Content.ReadAsStringAsync();
            if (!resp.IsSuccessStatusCode)
            {
                _logger.LogError("Geocoding '{Query}' failed: {Status} {Body}", query, (int)resp.StatusCode, body);
                throw new UserException("Pretraga adrese trenutno nije dostupna. Odaberite lokaciju na karti.");
            }

            return JArray.Parse(body)
                .Select(r => new GeocodingResultResponse
                {
                    DisplayName = (string?)r["display_name"] ?? string.Empty,
                    Latitude = double.Parse((string?)r["lat"] ?? "0", CultureInfo.InvariantCulture),
                    Longitude = double.Parse((string?)r["lon"] ?? "0", CultureInfo.InvariantCulture)
                })
                .ToList();
        }
    }
}
