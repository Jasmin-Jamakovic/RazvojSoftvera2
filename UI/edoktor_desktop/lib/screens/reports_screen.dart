import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/dashboard.dart';
import '../models/entities.dart';
import '../providers/providers.dart';
import '../services/report_pdf.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _ReportType { doctorPerformance, appointments }

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportType _type = _ReportType.doctorPerformance;
  String _status = ''; // appointments filter: '' = all

  // Cached data so the preview rebuild doesn't re-fetch on every layout pass.
  DashboardStats? _stats;
  List<Appointment>? _appts;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_type == _ReportType.doctorPerformance) {
        _stats = await context.read<DashboardProvider>().stats();
      } else {
        _appts = await context.read<AppointmentProvider>().list(status: _status.isEmpty ? null : _status);
      }
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    if (_type == _ReportType.doctorPerformance) {
      return ReportPdf.doctorPerformance(_stats!).save();
    }
    return ReportPdf.appointments(_appts ?? [], statusFilter: _status).save();
  }

  String get _fileName => _type == _ReportType.doctorPerformance
      ? 'izvjestaj-ucinak-ljekara.pdf'
      : 'izvjestaj-termini.pdf';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Izvještaji', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SegmentedButton<_ReportType>(
            segments: const [
              ButtonSegment(value: _ReportType.doctorPerformance, label: Text('Učinak ljekara'), icon: Icon(Icons.medical_services)),
              ButtonSegment(value: _ReportType.appointments, label: Text('Termini'), icon: Icon(Icons.event_note)),
            ],
            selected: {_type},
            onSelectionChanged: (s) { setState(() => _type = s.first); _load(); },
          ),
          if (_type == _ReportType.appointments)
            SizedBox(width: 220, child: DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
              items: const [
                DropdownMenuItem(value: '', child: Text('Svi statusi')),
                DropdownMenuItem(value: 'Pending', child: Text('Na čekanju')),
                DropdownMenuItem(value: 'Confirmed', child: Text('Potvrđeni')),
                DropdownMenuItem(value: 'Completed', child: Text('Završeni')),
                DropdownMenuItem(value: 'Cancelled', child: Text('Otkazani')),
              ],
              onChanged: (v) { setState(() => _status = v ?? ''); _load(); },
            )),
          if (!_loading && _error == null) ...[
            FilledButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Preuzmi PDF'),
              onPressed: () async {
                final bytes = await _buildPdf(PdfPageFormat.a4);
                await Printing.sharePdf(bytes: bytes, filename: _fileName);
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('Štampaj'),
              onPressed: () => Printing.layoutPdf(onLayout: _buildPdf, name: _fileName),
            ),
          ],
        ]),
        const SizedBox(height: 16),
        Expanded(child: Card(child: _buildPreview())),
      ]),
    );
  }

  Widget _buildPreview() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Greška pri učitavanju podataka: $_error', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _load, child: const Text('Pokušaj ponovo')),
      ])));
    }
    // PdfPreview renders the report inline and ships its own print/share toolbar,
    // so the report is both viewable and printable directly here.
    return PdfPreview(
      key: ValueKey('$_type-$_status'),
      build: _buildPdf,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      pdfFileName: _fileName,
    );
  }
}
