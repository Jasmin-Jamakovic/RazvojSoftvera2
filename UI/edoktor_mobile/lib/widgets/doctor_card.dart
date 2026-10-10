import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

class DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback? onTap;
  const DoctorCard({super.key, required this.doctor, this.onTap});

  @override
  Widget build(BuildContext context) {
    final specs = doctor.specializations.map((s) => s.name).join(', ');
    final city = doctor.clinic?.cityName;
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DoctorAvatar(doctor.fullName, size: 54, circle: false),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doctor.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.ink)),
            if (specs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(specs, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star_rounded, size: 16, color: AppColors.star),
                const SizedBox(width: 2),
                Text(doctor.averageRating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(' (${doctor.reviewCount})', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
              if (city != null && city.isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.muted),
                  const SizedBox(width: 2),
                  Text(city, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
            ]),
            if (doctor.recommendationReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: AppColors.tint2, borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(doctor.recommendationReason!,
                        style: const TextStyle(fontSize: 11, color: AppColors.primary, height: 1.3)),
                  ),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        Text('${doctor.consultationPrice.toStringAsFixed(0)} €',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
      ]),
    );
  }
}
