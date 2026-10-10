using eDoktor.Model;
using System;
using System.Threading.Tasks;
using eDoktor.Model.Responses;
using eDoktor.Services.Dashboard;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [ApiController, Route("api/dashboard"), Authorize(Roles = Roles.Admin)]
    public class DashboardController : ControllerBase
    {
        private readonly IDashboardService _svc;
        public DashboardController(IDashboardService svc) { _svc = svc; }

        [HttpGet("stats")]
        public Task<DashboardStatsResponse> Stats([FromQuery] int? year, [FromQuery] int? month, [FromQuery] int? specializationId)
            => _svc.GetStatsAsync(year, month, specializationId);

        [HttpGet("doctor-report")]
        public Task<DoctorReportResponse> DoctorReport([FromQuery] DateTime from, [FromQuery] DateTime to, [FromQuery] int? specializationId)
            => _svc.GetDoctorReportAsync(from, to, specializationId);
    }
}
