class DashboardStats {
  final int totalDoctors, totalPatients, totalAppointments, appointmentsToday;
  /// Selected month: gross = captured in the month, refunds = refunded in the month, revenue = net (gross − refunds).
  final double grossThisMonth, refundsThisMonth, revenueThisMonth;
  final DateTime monthStart;
  final String? topSpecialization, topDoctor;
  final double topDoctorRating;
  final List<DoctorRevenueRow> rows;
  DashboardStats({required this.totalDoctors, required this.totalPatients, required this.totalAppointments, required this.appointmentsToday, required this.grossThisMonth, required this.refundsThisMonth, required this.revenueThisMonth, required this.monthStart, this.topSpecialization, this.topDoctor, required this.topDoctorRating, required this.rows});
  factory DashboardStats.fromJson(Map<String, dynamic> j) => DashboardStats(
        totalDoctors: j['totalDoctors'] ?? 0, totalPatients: j['totalPatients'] ?? 0, totalAppointments: j['totalAppointments'] ?? 0, appointmentsToday: j['appointmentsToday'] ?? 0,
        grossThisMonth: (j['grossThisMonth'] ?? 0).toDouble(), refundsThisMonth: (j['refundsThisMonth'] ?? 0).toDouble(),
        revenueThisMonth: (j['revenueThisMonth'] ?? 0).toDouble(),
        monthStart: j['monthStart'] == null ? DateTime.now() : DateTime.parse(j['monthStart']).toLocal(),
        topSpecialization: j['topSpecialization'], topDoctor: j['topDoctor'], topDoctorRating: (j['topDoctorRating'] ?? 0).toDouble(),
        rows: (j['rows'] as List? ?? []).map((e) => DoctorRevenueRow.fromJson(e)).toList());
}
class DoctorRevenueRow {
  final int doctorId, appointmentCount;
  final String doctorName;
  final String? specialization;
  /// For the report's period: gross = captured in it, refunds = refunded in it, revenue = net.
  final double averageRating, grossRevenue, refunds, revenue;
  DoctorRevenueRow({required this.doctorId, required this.doctorName, this.specialization, required this.appointmentCount, required this.averageRating, required this.grossRevenue, required this.refunds, required this.revenue});
  factory DoctorRevenueRow.fromJson(Map<String, dynamic> j) => DoctorRevenueRow(
        doctorId: j['doctorId'], doctorName: j['doctorName'] ?? '', specialization: j['specialization'],
        appointmentCount: j['appointmentCount'] ?? 0, averageRating: (j['averageRating'] ?? 0).toDouble(),
        grossRevenue: (j['grossRevenue'] ?? 0).toDouble(), refunds: (j['refunds'] ?? 0).toDouble(),
        revenue: (j['revenue'] ?? 0).toDouble());
}

class DoctorReport {
  final DateTime from, to;
  final String? specializationName, topSpecialization, topDoctor;
  final int totalExams;
  final double totalGross, totalRefunds, totalRevenue, topDoctorRating;
  final List<DoctorRevenueRow> rows;
  DoctorReport({required this.from, required this.to, this.specializationName, required this.totalExams, required this.totalGross, required this.totalRefunds, required this.totalRevenue, this.topSpecialization, this.topDoctor, required this.topDoctorRating, required this.rows});
  factory DoctorReport.fromJson(Map<String, dynamic> j) => DoctorReport(
        from: DateTime.parse(j['from']), to: DateTime.parse(j['to']),
        specializationName: j['specializationName'],
        totalExams: j['totalExams'] ?? 0, totalRevenue: (j['totalRevenue'] ?? 0).toDouble(),
        totalGross: (j['totalGross'] ?? 0).toDouble(), totalRefunds: (j['totalRefunds'] ?? 0).toDouble(),
        topSpecialization: j['topSpecialization'], topDoctor: j['topDoctor'], topDoctorRating: (j['topDoctorRating'] ?? 0).toDouble(),
        rows: (j['rows'] as List? ?? []).map((e) => DoctorRevenueRow.fromJson(e)).toList());
}
