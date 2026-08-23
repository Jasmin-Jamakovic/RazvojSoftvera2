using eDoktor.Model;
using System.Collections.Generic;
using System.Threading.Tasks;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.TimeSlots;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [ApiController, Route("api/time-slots"), Authorize]
    public class TimeSlotsController : ControllerBase
    {
        private readonly ITimeSlotService _slots;
        public TimeSlotsController(ITimeSlotService slots) { _slots = slots; }

        [HttpGet]
        public Task<List<TimeSlotResponse>> Get([FromQuery] TimeSlotSearchObject s) => _slots.GetAsync(s ?? new());

        [HttpPost("generate"), Authorize(Roles = Roles.AdminOrDoctor)]
        public async Task<IActionResult> Generate(TimeSlotGenerateRequest req)
        {
            var n = await _slots.GenerateAsync(req);
            return Ok(new { generated = n });
        }
    }
}
