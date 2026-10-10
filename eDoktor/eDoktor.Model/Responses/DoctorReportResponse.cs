using System;
using System.Collections.Generic;

namespace eDoktor.Model.Responses
{
    // Doctor performance report for a chosen period (and optionally one specialization).
    public class DoctorReportResponse
    {
        public DateTime From { get; set; }
        public DateTime To { get; set; }
        public string? SpecializationName { get; set; }
        public int TotalExams { get; set; }
        public decimal TotalRevenue { get; set; }
        public string? TopSpecialization { get; set; }
        public string? TopDoctor { get; set; }
        public double TopDoctorRating { get; set; }
        public List<DoctorRevenueRow> Rows { get; set; } = new();
    }
}
