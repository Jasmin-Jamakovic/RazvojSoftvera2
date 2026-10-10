import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/dashboard.dart';
import '../models/entities.dart';
import '../providers/providers.dart';
import '../services/report_pdf.dart';
import '../utils/labels.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static final _date = DateFormat('dd.MM.yyyy');

  late DateTimeRange _range;
  late final Future<List<Specialization>> _specs;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: DateTime(now.year, now.month, 1), end: DateUtils.dateOnly(now));
    _specs = context.read<SpecializationProvider>().list();
  }

  /// The picker's end day is inclusive; the API takes an exclusive upper bound.
  DateTime get _toExclusive => DateTime(_range.end.year, _range.end.month, _range.end.day + 1);

  String get _periodText => '${_date.format(_range.start)} – ${_date.format(_range.end)}';

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range,
      helpText: 'Period izvještaja',
      saveText: 'Primijeni',
    );
    if (r != null) setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(length: 2, child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Izvještaji', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
        Tab(icon: Icon(Icons.medical_services), text: 'Učinak ljekara'),
        Tab(icon: Icon(Icons.event_note), text: 'Termini'),
      ]),
      const SizedBox(height: 16),
      Expanded(child: TabBarView(children: [
        _DoctorReportTab(range: () => _range, toExclusive: () => _toExclusive, periodText: () => _periodText, pickRange: _pickRange, specs: _specs),
        _AppointmentsReportTab(range: () => _range, toExclusive: () => _toExclusive, periodText: () => _periodText, pickRange: _pickRange),
      ])),
    ])));
  }
}

/// Period button shared by both tabs (the chosen period is kept when switching tabs).
class _PeriodButton extends StatelessWidget {
  final String text;
  final Future<void> Function() onPick;
  final VoidCallback onPicked;
  const _PeriodButton({required this.text, required this.onPick, required this.onPicked});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () async { await onPick(); onPicked(); },
        icon: const Icon(Icons.date_range),
        label: Text('Period: $text'),
      );
}

class _DoctorReportTab extends StatefulWidget {
  final DateTimeRange Function() range;
  final DateTime Function() toExclusive;
  final String Function() periodText;
  final Future<void> Function() pickRange;
  final Future<List<Specialization>> specs;
  const _DoctorReportTab({required this.range, required this.toExclusive, required this.periodText, required this.pickRange, required this.specs});

  @override
  State<_DoctorReportTab> createState() => _DoctorReportTabState();
}

class _DoctorReportTabState extends State<_DoctorReportTab> with AutomaticKeepAliveClientMixin {
  static final _money = NumberFormat.currency(symbol: '€', decimalDigits: 2);

  int? _specId;
  String? _specName;
  Future<DoctorReport>? _report;
  DoctorReport? _last;
  String _lastDescription = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() { super.initState(); _generate(); }

  void _generate() {
    final description = 'Period: ${widget.periodText()} · ${_specName == null ? 'Sve specijalizacije' : 'Specijalizacija: $_specName'}';
    setState(() {
      _report = context.read<DashboardProvider>()
          .doctorReport(from: widget.range().start, to: widget.toExclusive(), specializationId: _specId)
          .then((r) { _last = r; _lastDescription = description; return r; });
    });
  }

  Future<Uint8List> _pdf(PdfPageFormat _) => ReportPdf.doctorPerformance(_last!, filterDescription: _lastDescription).save();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        _PeriodButton(text: widget.periodText(), onPick: widget.pickRange, onPicked: () => setState(() {})),
        SizedBox(width: 240, child: FutureBuilder<List<Specialization>>(future: widget.specs, builder: (c, s) => DropdownButtonFormField<int?>(
          initialValue: _specId,
          decoration: const InputDecoration(labelText: 'Specijalizacija', border: OutlineInputBorder(), isDense: true),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Sve specijalizacije')),
            ...(s.data ?? []).map((x) => DropdownMenuItem<int?>(value: x.id, child: Text(x.name))),
          ],
          onChanged: (v) => setState(() {
            _specId = v;
            _specName = v == null ? null : s.data!.firstWhere((x) => x.id == v).name;
          }),
        ))),
        FilledButton.icon(onPressed: _generate, icon: const Icon(Icons.analytics), label: const Text('Generiši izvještaj')),
        OutlinedButton.icon(
          onPressed: _last == null ? null : () async => Printing.sharePdf(bytes: await _pdf(PdfPageFormat.a4), filename: 'izvjestaj-ucinak-ljekara.pdf'),
          icon: const Icon(Icons.download), label: const Text('Preuzmi PDF')),
        OutlinedButton.icon(
          onPressed: _last == null ? null : () => Printing.layoutPdf(onLayout: _pdf, name: 'izvjestaj-ucinak-ljekara.pdf'),
          icon: const Icon(Icons.print), label: const Text('Štampaj')),
      ]),
      const SizedBox(height: 16),
      Expanded(child: FutureBuilder<DoctorReport>(future: _report, builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('Izvještaj nije moguće generisati: ${s.error}', style: const TextStyle(color: Colors.red)));
        final r = s.data!;
        return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_lastDescription, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          Wrap(spacing: 16, runSpacing: 16, children: [
            _stat('Ukupno pregleda', '${r.totalExams}', Icons.event_available),
            _stat('Prihod', _money.format(r.totalRevenue), Icons.euro),
            _stat('Najtraženija specijalizacija', r.topSpecialization ?? '-', Icons.star),
            _stat('Najbolje ocijenjen ljekar', r.topDoctor == null ? '-' : '${r.topDoctor} (${r.topDoctorRating.toStringAsFixed(1)})', Icons.emoji_events),
          ]),
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Broj obavljenih pregleda po ljekaru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(height: 260, child: r.rows.isEmpty
                ? const Center(child: Text('Nema ljekara za odabrane filtere.'))
                : _chart(r.rows)),
          ]))),
          const SizedBox(height: 16),
          Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [
            DataColumn(label: Text('Ljekar')),
            DataColumn(label: Text('Specijalizacija')),
            DataColumn(label: Text('Broj pregleda'), numeric: true),
            DataColumn(label: Text('Prosječna ocjena'), numeric: true),
            DataColumn(label: Text('Prihod'), numeric: true),
          ], rows: [
            ...r.rows.map((x) => DataRow(cells: [
              DataCell(Text('dr. ${x.doctorName}')),
              DataCell(Text(x.specialization ?? '-')),
              DataCell(Text('${x.appointmentCount}')),
              DataCell(Text(x.averageRating == 0 ? 'Bez ocjena' : x.averageRating.toStringAsFixed(1))),
              DataCell(Text(_money.format(x.revenue))),
            ])),
            DataRow(color: WidgetStateProperty.all(const Color(0xFFF2F5F9)), cells: [
              const DataCell(Text('UKUPNO', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataCell(Text('')),
              DataCell(Text('${r.totalExams}', style: const TextStyle(fontWeight: FontWeight.bold))),
              const DataCell(Text('')),
              DataCell(Text(_money.format(r.totalRevenue), style: const TextStyle(fontWeight: FontWeight.bold))),
            ]),
          ]))),
        ]));
      })),
    ]);
  }

  Widget _chart(List<DoctorRevenueRow> rows) {
    final maxY = rows.fold<int>(0, (m, r) => r.appointmentCount > m ? r.appointmentCount : m);
    return BarChart(BarChartData(
      maxY: (maxY < 4 ? 4 : maxY + 1).toDouble(),
      alignment: BarChartAlignment.spaceAround,
      barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
        getTooltipItem: (group, _, rod, __) => BarTooltipItem('dr. ${rows[group.x].doctorName}\n${rod.toY.toInt()} pregleda', const TextStyle(color: Colors.white)),
      )),
      barGroups: [
        for (var i = 0; i < rows.length; i++)
          BarChartGroupData(x: i, barRods: [BarChartRodData(toY: rows[i].appointmentCount.toDouble(), color: const Color(0xFF2E7D32), width: 26, borderRadius: BorderRadius.circular(4))]),
      ],
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: 1,
          getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 11)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, _) {
          final i = v.toInt();
          if (i < 0 || i >= rows.length) return const SizedBox();
          return Padding(padding: const EdgeInsets.only(top: 6), child: Text(rows[i].doctorName.split(' ').last, style: const TextStyle(fontSize: 11)));
        })),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(drawVerticalLine: false, horizontalInterval: 1),
      borderData: FlBorderData(show: false),
    ));
  }

  Widget _stat(String label, String value, IconData icon) => Container(
    width: 260, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: const Color(0xFF2E7D32)), const SizedBox(width: 8), Expanded(child: Text(label, style: const TextStyle(color: Colors.grey)))]),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    ]),
  );
}

class _AppointmentsReportTab extends StatefulWidget {
  final DateTimeRange Function() range;
  final DateTime Function() toExclusive;
  final String Function() periodText;
  final Future<void> Function() pickRange;
  const _AppointmentsReportTab({required this.range, required this.toExclusive, required this.periodText, required this.pickRange});

  @override
  State<_AppointmentsReportTab> createState() => _AppointmentsReportTabState();
}

class _AppointmentsReportTabState extends State<_AppointmentsReportTab> with AutomaticKeepAliveClientMixin {
  String? _status;
  Future<List<Appointment>>? _items;
  String _description = '';
  int _version = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() { super.initState(); _generate(); }

  void _generate() {
    setState(() {
      _version++;
      _description = 'Period: ${widget.periodText()} · ${_status == null ? 'Svi statusi' : 'Status: ${appointmentStatusLabel(_status)}'}';
      _items = context.read<AppointmentProvider>().listAll(status: _status, from: widget.range().start, to: widget.toExclusive());
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        _PeriodButton(text: widget.periodText(), onPick: widget.pickRange, onPicked: () => setState(() {})),
        SizedBox(width: 220, child: DropdownButtonFormField<String?>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: null, child: Text('Svi statusi')),
            DropdownMenuItem(value: 'Pending', child: Text('Na čekanju')),
            DropdownMenuItem(value: 'Confirmed', child: Text('Potvrđeni')),
            DropdownMenuItem(value: 'Completed', child: Text('Završeni')),
            DropdownMenuItem(value: 'Cancelled', child: Text('Otkazani')),
          ],
          onChanged: (v) => setState(() => _status = v),
        )),
        FilledButton.icon(onPressed: _generate, icon: const Icon(Icons.analytics), label: const Text('Generiši izvještaj')),
      ]),
      const SizedBox(height: 16),
      Expanded(child: Card(child: FutureBuilder<List<Appointment>>(future: _items, builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('Izvještaj nije moguće generisati: ${s.error}', style: const TextStyle(color: Colors.red)));
        final items = s.data!;
        // PdfPreview shows the report inline and has its own print / download toolbar.
        return PdfPreview(
          key: ValueKey(_version),
          build: (_) => ReportPdf.appointments(items, filterDescription: _description).save(),
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          pdfFileName: 'izvjestaj-termini.pdf',
        );
      }))),
    ]);
  }
}
