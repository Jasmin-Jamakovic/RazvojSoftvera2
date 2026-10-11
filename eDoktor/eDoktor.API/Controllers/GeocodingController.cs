using System.Collections.Generic;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Responses;
using eDoktor.Services.Geocoding;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [ApiController, Route("api/geocoding"), Authorize(Roles = Roles.Admin)]
    public class GeocodingController : ControllerBase
    {
        private readonly IGeocodingService _geocoding;
        public GeocodingController(IGeocodingService geocoding) { _geocoding = geocoding; }

        [HttpGet]
        public Task<List<GeocodingResultResponse>> Search([FromQuery] string address, [FromQuery] int? cityId)
            => _geocoding.SearchAsync(address, cityId);
    }
}
