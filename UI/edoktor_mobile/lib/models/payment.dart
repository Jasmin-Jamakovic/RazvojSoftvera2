class Payment {
  final int id;
  final double amount;
  final String currency;
  final String status;
  final DateTime createdAt;
  final DateTime? capturedAt;
  final DateTime? refundedAt;
  final String? doctorName;
  final DateTime? appointmentStart;
  final String? appointmentStatus;

  Payment({
    required this.id, required this.amount, required this.currency, required this.status, required this.createdAt,
    this.capturedAt, this.refundedAt, this.doctorName, this.appointmentStart, this.appointmentStatus,
  });

  static DateTime? _d(dynamic v) => v == null ? null : DateTime.parse(v).toLocal();

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'],
        amount: (j['amount'] ?? 0).toDouble(),
        currency: j['currency'] ?? 'EUR',
        status: j['status'] ?? '',
        createdAt: DateTime.parse(j['createdAt']).toLocal(),
        capturedAt: _d(j['capturedAt']),
        refundedAt: _d(j['refundedAt']),
        doctorName: j['doctorName'],
        appointmentStart: _d(j['appointmentStartUtc']),
        appointmentStatus: j['appointmentStatus'],
      );
}

class PaymentSummary {
  final double totalCaptured, totalRefunded, netRevenue;
  PaymentSummary({required this.totalCaptured, required this.totalRefunded, required this.netRevenue});
  factory PaymentSummary.fromJson(Map<String, dynamic> j) => PaymentSummary(
        totalCaptured: (j['totalCaptured'] ?? 0).toDouble(),
        totalRefunded: (j['totalRefunded'] ?? 0).toDouble(),
        netRevenue: (j['netRevenue'] ?? 0).toDouble(),
      );
}
