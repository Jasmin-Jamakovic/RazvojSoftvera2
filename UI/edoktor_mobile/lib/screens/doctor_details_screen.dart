import 'package:flutter/material.dart';
import '../models/doctor.dart';
import 'appointment_booking_screen.dart';

class DoctorDetailsScreen extends StatelessWidget {
  final Doctor doctor;
  const DoctorDetailsScreen({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    final specs = doctor.specializations.map((s) => s.name).join(' • ');
    return Scaffold(
      appBar: AppBar(title: Text(doctor.fullName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 36, backgroundColor: const Color(0xFFE3F2FD), child: Text('${doctor.firstName.isNotEmpty ? doctor.firstName[0] : ''}${doctor.lastName.isNotEmpty ? doctor.lastName[0] : ''}', style: const TextStyle(color: Color(0xFF0D47A1), fontSize: 24, fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doctor.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(specs, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              Row(children: [
                ...List.generate(5, (i) => Icon(i < doctor.averageRating.round() ? Icons.star : Icons.star_border, size: 18, color: Colors.amber)),
                const SizedBox(width: 6),
                Text('${doctor.averageRating.toStringAsFixed(1)} (${doctor.reviewCount})'),
              ]),
            ])),
          ]),
          const SizedBox(height: 16),
          if (doctor.clinic != null) Row(children: [const Icon(Icons.location_on_outlined, size: 16), const SizedBox(width: 4), Text('${doctor.clinic!.name}, ${doctor.clinic!.cityName ?? ''}')]),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.work_outline, size: 16), const SizedBox(width: 4), Text('${doctor.yearsExperience} god. iskustva  •  ${doctor.consultationPrice.toStringAsFixed(0)} EUR')]),
          const SizedBox(height: 16),
          if (doctor.bio != null) ...[const Text('O ljekaru', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(doctor.bio!)],
          const Spacer(),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentBookingScreen(doctor: doctor))),
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Zakaži termin')))),
        ]),
      ),
    );
  }
}
