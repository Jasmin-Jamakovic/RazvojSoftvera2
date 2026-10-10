using System;
using System.Threading.Tasks;
using eDoktor.Model.Responses;

namespace eDoktor.Services.Dashboard
{
    public interface IDashboardService
    {
        Task<DashboardStatsResponse> GetStatsAsync(int? year = null, int? month = null, int? specializationId = null);
        Task<DoctorReportResponse> GetDoctorReportAsync(DateTime from, DateTime to, int? specializationId);
    }
}
