using System.Collections.Generic;

namespace eDoktor.Model.Responses
{
    public class DashboardStatsResponse
    {
        public int TotalDoctors { get; set; }
        public int TotalPatients { get; set; }
        public int TotalAppointments { get; set; }
        public int AppointmentsToday { get; set; }
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
        public decimal Revenue { get; set; }
    }
}
