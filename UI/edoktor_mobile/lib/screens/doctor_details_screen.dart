import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/doctor.dart';
import '../models/review.dart';
import '../providers/doctor_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'appointment_booking_screen.dart';

class DoctorDetailsScreen extends StatelessWidget {
  final Doctor doctor;
  const DoctorDetailsScreen({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    final specs = doctor.specializations.map((s) => s.name).join(' · ');
    final top = MediaQuery.of(context).padding.top + 8;
    return Scaffold(
      body: Column(children: [
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            Container(
              padding: EdgeInsets.fromLTRB(16, top, 16, 64),
              decoration: const BoxDecoration(
                gradient: AppColors.gradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(children: [
                Row(children: [
                  IconSquare.onGradient(Icons.arrow_back, size: 36, iconSize: 18, onTap: () => Navigator.pop(context)),
                ]),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.25)),
                  child: DoctorPhoto(doctorId: doctor.id, name: doctor.fullName, hasPhoto: doctor.hasPhoto, size: 88),
                ),
                const SizedBox(height: 12),
                Text(doctor.fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
                if (specs.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(specs, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                ],
              ]),
            ),
            // Stats card and body are lifted together so the card overlaps the header without leaving a gap.
            Transform.translate(
              offset: const Offset(0, -40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AppCard(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: IntrinsicHeight(
                    child: Row(children: [
                      _Stat(value: doctor.averageRating.toStringAsFixed(1), label: 'Ocjena', icon: Icons.star_rounded),
                      const VerticalDivider(width: 1, color: AppColors.line),
                      _Stat(value: '${doctor.yearsExperience} god.', label: 'Iskustvo'),
                      const VerticalDivider(width: 1, color: AppColors.line),
                      _Stat(value: '${doctor.reviewCount}', label: 'Recenzija'),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (doctor.bio != null && doctor.bio!.isNotEmpty) ...[
                      const Text('O ljekaru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(doctor.bio!, style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF4A5263))),
                      const SizedBox(height: 16),
                    ],
                    if (doctor.clinic != null) ...[
                      _InfoRow(
                        icon: Icons.local_hospital_outlined,
                        label: 'Klinika',
                        value: [doctor.clinic!.name, doctor.clinic!.cityName].whereType<String>().where((s) => s.isNotEmpty).join(', '),
                        sub: doctor.clinic!.address,
                      ),
                      const SizedBox(height: 10),
                    ],
                    const _InfoRow(icon: Icons.videocam_outlined, label: 'Vrste pregleda', value: 'Uživo · Online konsultacija'),
                    const SizedBox(height: 20),
                    _ReviewsSection(doctorId: doctor.id),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Color(0x14142346), blurRadius: 16, offset: Offset(0, -4))],
          ),
          child: Row(children: [
            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Cijena pregleda', style: TextStyle(fontSize: 11, color: AppColors.muted)),
              Text('${doctor.consultationPrice.toStringAsFixed(0)} €',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ]),
            const SizedBox(width: 16),
            Expanded(
              child: GradientButton(
                label: 'Zakaži termin',
                icon: Icons.event_outlined,
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentBookingScreen(doctor: doctor))),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  const _Stat({required this.value, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[Icon(icon, size: 18, color: AppColors.star), const SizedBox(width: 2)],
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ]),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  const _InfoRow({required this.icon, required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        IconSquare(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            if (sub != null && sub!.isNotEmpty) Text(sub!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
      ]),
    );
  }
}

/// Latest patient reviews of the doctor.
class _ReviewsSection extends StatefulWidget {
  final int doctorId;
  const _ReviewsSection({required this.doctorId});
  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  late final Future<(List<Review>, int)> _f = context.read<DoctorProvider>().reviews(widget.doctorId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<Review>, int)>(future: _f, builder: (c, s) {
      if (s.connectionState != ConnectionState.done) {
        return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
      }
      if (s.hasError) return Text('Recenzije nije moguće učitati: ${s.error}', style: const TextStyle(color: AppColors.muted));
      final (items, total) = s.data!;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(total > items.length ? 'Recenzije pacijenata (${items.length} od $total)' : 'Recenzije pacijenata',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text('Ljekar još nema recenzija.', style: TextStyle(color: AppColors.muted))
        else
          for (final r in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    for (var i = 1; i <= 5; i++)
                      Icon(i <= r.rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 16, color: AppColors.star),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r.patientName?.trim().isNotEmpty == true ? r.patientName! : 'Pacijent',
                        overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    Text('${r.createdAt.day}.${r.createdAt.month}.${r.createdAt.year}.', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ]),
                  if (r.comment?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(r.comment!, style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF4A5263))),
                  ],
                ]),
              ),
            ),
      ]);
    });
  }
}
