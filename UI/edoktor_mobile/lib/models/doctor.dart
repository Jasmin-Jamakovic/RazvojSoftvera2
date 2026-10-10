import 'clinic.dart';
import 'specialization.dart';

class Doctor {
  final int id;
  final String firstName;
  final String lastName;
  final String? bio;
  final int yearsExperience;
  final double consultationPrice;
  final Clinic? clinic;
  final List<Specialization> specializations;
  final double averageRating;
  final int reviewCount;
  final String? recommendationReason;
  final bool hasPhoto;

  Doctor({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.bio,
    required this.yearsExperience,
    required this.consultationPrice,
    this.clinic,
    required this.specializations,
    required this.averageRating,
    required this.reviewCount,
    this.recommendationReason,
    this.hasPhoto = false,
  });

  String get fullName => 'Dr. $firstName $lastName'.trim();

  factory Doctor.fromJson(Map<String, dynamic> j) => Doctor(
        id: j['id'],
        firstName: j['firstName'] ?? '',
        lastName: j['lastName'] ?? '',
        bio: j['bio'],
        yearsExperience: j['yearsExperience'] ?? 0,
        consultationPrice: (j['consultationPrice'] ?? 0).toDouble(),
        clinic: j['clinic'] == null ? null : Clinic.fromJson(j['clinic']),
        specializations: (j['specializations'] as List? ?? []).map((e) => Specialization.fromJson(e)).toList(),
        averageRating: (j['averageRating'] ?? 0).toDouble(),
        reviewCount: j['reviewCount'] ?? 0,
        recommendationReason: j['recommendationReason'],
        hasPhoto: j['hasPhoto'] ?? false,
      );
}
