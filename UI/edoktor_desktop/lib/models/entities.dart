class Specialization {
  final int id; final String name; final String? description;
  Specialization({required this.id, required this.name, this.description});
  factory Specialization.fromJson(Map<String, dynamic> j) => Specialization(id: j['id'], name: j['name'] ?? '', description: j['description']);
}

class Clinic {
  final int id; final String name; final String? address; final int? cityId; final String? cityName;
  Clinic({required this.id, required this.name, this.address, this.cityId, this.cityName});
  factory Clinic.fromJson(Map<String, dynamic> j) => Clinic(id: j['id'], name: j['name'] ?? '', address: j['address'], cityId: j['cityId'], cityName: j['cityName']);
}

class City {
  final int id; final String name; final String? country;
  City({required this.id, required this.name, this.country});
  factory City.fromJson(Map<String, dynamic> j) => City(id: j['id'], name: j['name'] ?? '', country: j['country']);
}

class Doctor {
  final int id; final String firstName, lastName; final String? bio;
  final int yearsExperience; final double consultationPrice;
  final Clinic? clinic; final List<Specialization> specializations;
  final double averageRating; final int reviewCount; final bool hasPhoto;
  Doctor({required this.id, required this.firstName, required this.lastName, this.bio, required this.yearsExperience, required this.consultationPrice, this.clinic, required this.specializations, required this.averageRating, required this.reviewCount, this.hasPhoto = false});
  String get fullName => 'Dr. $firstName $lastName';
  factory Doctor.fromJson(Map<String, dynamic> j) => Doctor(
        id: j['id'], firstName: j['firstName'] ?? '', lastName: j['lastName'] ?? '',
        bio: j['bio'], yearsExperience: j['yearsExperience'] ?? 0, consultationPrice: (j['consultationPrice'] ?? 0).toDouble(),
        clinic: j['clinic'] == null ? null : Clinic.fromJson(j['clinic']),
        specializations: (j['specializations'] as List? ?? []).map((e) => Specialization.fromJson(e)).toList(),
        averageRating: (j['averageRating'] ?? 0).toDouble(), reviewCount: j['reviewCount'] ?? 0,
        hasPhoto: j['hasPhoto'] ?? false);
}

class Appointment {
  final int id; final int patientId, doctorId;
  final String? patientName, doctorName;
  final DateTime startUtc;
  final int type;
  final String status;
  final double price;
  final Map<String, dynamic>? payment;
  final String? cancellationReason;
  Appointment({required this.id, required this.patientId, this.patientName, required this.doctorId, this.doctorName, required this.startUtc, required this.type, required this.status, required this.price, this.payment, this.cancellationReason});
  bool get isOnline => type == 1;
  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'], patientId: j['patientId'], patientName: j['patientName'],
        doctorId: j['doctorId'], doctorName: j['doctorName'],
        startUtc: DateTime.parse(j['startUtc']).toLocal(),
        type: j['type'] ?? 0, status: j['status'] ?? 'Pending',
        price: (j['price'] ?? 0).toDouble(),
        payment: j['payment'] as Map<String, dynamic>?,
        cancellationReason: j['cancellationReason']);
}

class TimeSlot {
  final int id;
  final DateTime start, end;
  final bool isBooked;
  TimeSlot({required this.id, required this.start, required this.end, this.isBooked = false});
  factory TimeSlot.fromJson(Map<String, dynamic> j) => TimeSlot(
        id: j['id'], start: DateTime.parse(j['startUtc']).toLocal(), end: DateTime.parse(j['endUtc']).toLocal(),
        isBooked: j['isBooked'] ?? false);
}

class Payment {
  final int id, appointmentId;
  final String? captureId;
  final double amount;
  final String currency, status;
  final DateTime createdAt;
  final DateTime? capturedAt, refundedAt, appointmentStart;
  final String? patientName, doctorName, appointmentStatus;
  Payment({required this.id, required this.appointmentId, this.captureId, required this.amount, required this.currency, required this.status, required this.createdAt, this.capturedAt, this.refundedAt, this.appointmentStart, this.patientName, this.doctorName, this.appointmentStatus});
  bool get canRefund => status == 'Captured' && captureId != null && appointmentStatus == 'Cancelled';
  static DateTime? _d(dynamic v) => v == null ? null : DateTime.parse(v).toLocal();
  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'], appointmentId: j['appointmentId'], captureId: j['captureId'],
        amount: (j['amount'] ?? 0).toDouble(), currency: j['currency'] ?? 'EUR', status: j['status'] ?? '',
        createdAt: DateTime.parse(j['createdAt']).toLocal(),
        capturedAt: _d(j['capturedAt']), refundedAt: _d(j['refundedAt']), appointmentStart: _d(j['appointmentStartUtc']),
        patientName: j['patientName'], doctorName: j['doctorName'], appointmentStatus: j['appointmentStatus']);
}

class PaymentSummary {
  final double totalCaptured, totalRefunded, netRevenue;
  final int capturedCount, refundedCount, pendingCount;
  PaymentSummary({required this.totalCaptured, required this.totalRefunded, required this.netRevenue, required this.capturedCount, required this.refundedCount, required this.pendingCount});
  factory PaymentSummary.fromJson(Map<String, dynamic> j) => PaymentSummary(
        totalCaptured: (j['totalCaptured'] ?? 0).toDouble(), totalRefunded: (j['totalRefunded'] ?? 0).toDouble(),
        netRevenue: (j['netRevenue'] ?? 0).toDouble(), capturedCount: j['capturedCount'] ?? 0,
        refundedCount: j['refundedCount'] ?? 0, pendingCount: j['pendingCount'] ?? 0);
}

class PagedList<T> {
  final List<T> items;
  final int totalCount;
  PagedList(this.items, this.totalCount);
}
