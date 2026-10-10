class DashboardStats {
  final int totalDoctors, totalPatients, totalAppointments, appointmentsToday;
  final double revenueThisMonth;
  final String? topSpecialization, topDoctor;
  final double topDoctorRating;
  final List<DoctorRevenueRow> rows;
  DashboardStats({required this.totalDoctors, required this.totalPatients, required this.totalAppointments, required this.appointmentsToday, required this.revenueThisMonth, this.topSpecialization, this.topDoctor, required this.topDoctorRating, required this.rows});
  factory DashboardStats.fromJson(Map<String, dynamic> j) => DashboardStats(
        totalDoctors: j['totalDoctors'] ?? 0, totalPatients: j['totalPatients'] ?? 0, totalAppointments: j['totalAppointments'] ?? 0, appointmentsToday: j['appointmentsToday'] ?? 0,
        revenueThisMonth: (j['revenueThisMonth'] ?? 0).toDouble(),
        topSpecialization: j['topSpecialization'], topDoctor: j['topDoctor'], topDoctorRating: (j['topDoctorRating'] ?? 0).toDouble(),
        rows: (j['rows'] as List? ?? []).map((e) => DoctorRevenueRow.fromJson(e)).toList());
}
class DoctorRevenueRow {
  final int doctorId, appointmentCount;
  final String doctorName;
  final String? specialization;
  final double averageRating, revenue;
  DoctorRevenueRow({required this.doctorId, required this.doctorName, this.specialization, required this.appointmentCount, required this.averageRating, required this.revenue});
  factory DoctorRevenueRow.fromJson(Map<String, dynamic> j) => DoctorRevenueRow(
        doctorId: j['doctorId'], doctorName: j['doctorName'] ?? '', specialization: j['specialization'],
        appointmentCount: j['appointmentCount'] ?? 0, averageRating: (j['averageRating'] ?? 0).toDouble(),
        revenue: (j['revenue'] ?? 0).toDouble());
}

class DoctorReport {
  final DateTime from, to;
  final String? specializationName, topSpecialization, topDoctor;
  final int totalExams;
  final double totalRevenue, topDoctorRating;
  final List<DoctorRevenueRow> rows;
  DoctorReport({required this.from, required this.to, this.specializationName, required this.totalExams, required this.totalRevenue, this.topSpecialization, this.topDoctor, required this.topDoctorRating, required this.rows});
  factory DoctorReport.fromJson(Map<String, dynamic> j) => DoctorReport(
        from: DateTime.parse(j['from']), to: DateTime.parse(j['to']),
        specializationName: j['specializationName'],
        totalExams: j['totalExams'] ?? 0, totalRevenue: (j['totalRevenue'] ?? 0).toDouble(),
        topSpecialization: j['topSpecialization'], topDoctor: j['topDoctor'], topDoctorRating: (j['topDoctorRating'] ?? 0).toDouble(),
        rows: (j['rows'] as List? ?? []).map((e) => DoctorRevenueRow.fromJson(e)).toList());
}
