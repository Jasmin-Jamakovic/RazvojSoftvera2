import 'package:flutter/material.dart';
import '../models/doctor.dart';

class DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback? onTap;
  const DoctorCard({super.key, required this.doctor, this.onTap});

  @override
  Widget build(BuildContext context) {
    final specs = doctor.specializations.map((s) => s.name).join(', ');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 32, backgroundColor: const Color(0xFFE3F2FD), child: Text('${doctor.firstName.isNotEmpty ? doctor.firstName[0] : ''}${doctor.lastName.isNotEmpty ? doctor.lastName[0] : ''}', style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold, fontSize: 20))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doctor.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(specs, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 6),
              Row(children: [
                ...List.generate(5, (i) => Icon(i < doctor.averageRating.round() ? Icons.star : Icons.star_border, size: 16, color: Colors.amber)),
                const SizedBox(width: 6),
                Text('(${doctor.reviewCount})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
              if (doctor.recommendationReason != null) ...[
                const SizedBox(height: 4),
                Text(doctor.recommendationReason!, style: const TextStyle(fontSize: 11, color: Color(0xFF0D47A1), fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 6),
              Text('${doctor.consultationPrice.toStringAsFixed(0)} EUR  •  ${doctor.clinic?.cityName ?? ''}', style: const TextStyle(fontSize: 12)),
            ])),
          ]),
        ),
      ),
    );
  }
}
