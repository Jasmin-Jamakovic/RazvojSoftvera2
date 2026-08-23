class TimeSlot {
  final int id;
  final int doctorId;
  final DateTime startUtc;
  final DateTime endUtc;
  final bool isBooked;
  TimeSlot({required this.id, required this.doctorId, required this.startUtc, required this.endUtc, required this.isBooked});
  factory TimeSlot.fromJson(Map<String, dynamic> j) => TimeSlot(
        id: j['id'],
        doctorId: j['doctorId'],
        startUtc: DateTime.parse(j['startUtc']).toLocal(),
        endUtc: DateTime.parse(j['endUtc']).toLocal(),
        isBooked: j['isBooked'] ?? false,
      );
}
