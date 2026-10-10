import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medical_record.dart';
import '../services/record_pdf.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Detail view of one medical record item (visit, prescription or lab result) with a PDF download.
class RecordDetailsScreen extends StatefulWidget {
  final String title;
  final IconData icon;
  final String heading;
  final String subtitle;
  final List<Widget> Function(BuildContext context) body;
  final Future<Uint8List> Function() buildPdf;
  final String pdfFileName;
  final String pdfLabel;

  const RecordDetailsScreen._({
    required this.title,
    required this.icon,
    required this.heading,
    required this.subtitle,
    required this.body,
    required this.buildPdf,
    required this.pdfFileName,
    required this.pdfLabel,
  });

  static final _date = DateFormat('dd.MM.yyyy.');
  static final _dateTime = DateFormat('dd.MM.yyyy. HH:mm');

  factory RecordDetailsScreen.visit(MedicalRecord r, MedicalRecordEntry e) => RecordDetailsScreen._(
        title: 'Detalji pregleda',
        icon: Icons.medical_services_outlined,
        heading: e.diagnosis ?? 'Pregled',
        subtitle: [_dateTime.format(e.appointmentDate), e.doctorName, e.specialization].whereType<String>().join(' · '),
        body: (c) => [
          _Section(icon: Icons.healing_outlined, title: 'Dijagnoza', text: e.diagnosis),
          _Section(icon: Icons.medical_services_outlined, title: 'Terapija', text: e.therapy),
          _Section(icon: Icons.notes_outlined, title: 'Napomene ljekara', text: e.notes),
          const SizedBox(height: 4),
          const Text('E-recept sa ovog pregleda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (e.prescription == null)
            const Text('Na ovom pregledu nije izdat recept.', style: TextStyle(color: AppColors.muted))
          else
            _PrescriptionItems(prescription: e.prescription!),
        ],
        buildPdf: () => RecordPdf.visit(r, e),
        pdfFileName: 'izvjestaj-${DateFormat('yyyy-MM-dd').format(e.appointmentDate)}.pdf',
        pdfLabel: 'Preuzmi izvještaj (PDF)',
      );

  factory RecordDetailsScreen.prescription(MedicalRecord r, Prescription p) => RecordDetailsScreen._(
        title: 'E-recept',
        icon: Icons.medication_outlined,
        heading: 'Recept ${RecordPdf.prescriptionNumber(p)}',
        subtitle: [_date.format(p.issuedAt), if (p.doctorName != null) 'dr. ${p.doctorName}'].join(' · '),
        body: (c) => [
          _PrescriptionItems(prescription: p),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.tint2, borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(child: Text('Preuzmite recept i pokažite ga u apoteci zajedno sa ličnim dokumentom.', style: TextStyle(fontSize: 13))),
            ]),
          ),
        ],
        buildPdf: () => RecordPdf.prescription(r, p),
        pdfFileName: 'e-recept-${RecordPdf.prescriptionNumber(p)}.pdf',
        pdfLabel: 'Preuzmi recept (PDF)',
      );

  factory RecordDetailsScreen.lab(MedicalRecord r, LabResult l) => RecordDetailsScreen._(
        title: 'Laboratorijski nalaz',
        icon: Icons.description_outlined,
        heading: l.title,
        subtitle: _date.format(l.createdAt),
        body: (c) => [_Section(icon: Icons.science_outlined, title: 'Rezultat i napomene', text: l.notes)],
        buildPdf: () => RecordPdf.labResult(r, l),
        pdfFileName: 'nalaz-${DateFormat('yyyy-MM-dd').format(l.createdAt)}.pdf',
        pdfLabel: 'Preuzmi nalaz (PDF)',
      );

  @override
  State<RecordDetailsScreen> createState() => _RecordDetailsScreenState();
}

class _RecordDetailsScreenState extends State<RecordDetailsScreen> {
  bool _busy = false;

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      await RecordPdf.share(widget.buildPdf(), widget.pdfFileName);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF nije moguće kreirati: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          child: Row(children: [
            IconSquare(widget.icon, size: 46, iconSize: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.heading, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text(widget.subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        ...widget.body(context),
      ]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: GradientButton(label: widget.pdfLabel, icon: Icons.download_outlined, busy: _busy, onPressed: _download),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? text;
  const _Section({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            Text((text == null || text!.trim().isEmpty) ? '-' : text!, style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF4A5263))),
          ]),
        ),
      );
}

class _PrescriptionItems extends StatelessWidget {
  final Prescription prescription;
  const _PrescriptionItems({required this.prescription});

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final i in prescription.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const IconSquare(Icons.medication_outlined, size: 36, iconSize: 18, color: Color(0xFF7B1FA2), background: Color(0xFFF3E8FD)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i.medication, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text([i.dosage, i.frequency, i.duration].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                        style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ]),
                ),
              ]),
            ),
          ),
      ]);
}
