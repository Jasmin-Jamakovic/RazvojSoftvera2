using System.Collections.Generic;

namespace eDoktor.Model.Responses
{
    public class DashboardStatsResponse
    {
        public int TotalDoctors { get; set; }
        public int TotalPatients { get; set; }
        public int TotalAppointments { get; set; }
        public int AppointmentsToday { get; set; }
        // Money for the selected month (local calendar), see MonthStart/MonthEnd:
        // gross = captured in the month, refunds = refunded in the month, net (RevenueThisMonth) = gross - refunds.
        public System.DateTime MonthStart { get; set; }
        public System.DateTime MonthEnd { get; set; }
        public decimal GrossThisMonth { get; set; }
        public decimal RefundsThisMonth { get; set; }
        public decimal RevenueThisMonth { get; set; }
        public string? TopSpecialization { get; set; }
        public string? TopDoctor { get; set; }
        public double TopDoctorRating { get; set; }
        public List<DoctorRevenueRow> Rows { get; set; } = new();
    }

    public class DoctorRevenueRow
    {
        public int DoctorId { get; set; }
        public string DoctorName { get; set; } = string.Empty;
        public string? Specialization { get; set; }
        public int AppointmentCount { get; set; }
        public double AverageRating { get; set; }
        // For the period of the report: captured in the period, refunded in the period, and net = the difference.
        public decimal GrossRevenue { get; set; }
        public decimal Refunds { get; set; }
        public decimal Revenue { get; set; }
    }
}
