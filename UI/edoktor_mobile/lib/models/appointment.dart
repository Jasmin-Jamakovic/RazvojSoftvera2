class Appointment {
  final int id;
  final int patientId;
  final String? patientName;
  final int doctorId;
  final String? doctorName;
  final DateTime startUtc;
  final DateTime endUtc;
  final int type;
  final String status;
  final double price;
  final String? videoRoomId;
  final Map<String, dynamic>? payment;
  final bool isPaid;
  final int? reviewRating;

  Appointment({
    required this.id, required this.patientId, this.patientName,
    required this.doctorId, this.doctorName,
    required this.startUtc, required this.endUtc,
    required this.type, required this.status, required this.price,
    this.videoRoomId, this.payment, this.isPaid = false, this.reviewRating,
  });

  bool get isOnline => type == 1;
  String get typeLabel => isOnline ? 'Online' : 'Uživo';
  bool get canReview => status == 'Completed' && reviewRating == null;

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'],
        patientId: j['patientId'],
        patientName: j['patientName'],
        doctorId: j['doctorId'],
        doctorName: j['doctorName'],
        startUtc: DateTime.parse(j['startUtc']).toLocal(),
        endUtc: DateTime.parse(j['endUtc']).toLocal(),
        type: j['type'] ?? 0,
        status: j['status'] ?? 'Pending',
        price: (j['price'] ?? 0).toDouble(),
        videoRoomId: j['videoRoomId'],
        payment: j['payment'] as Map<String, dynamic>?,
        isPaid: j['isPaid'] ?? false,
        reviewRating: j['reviewRating'],
      );
}
