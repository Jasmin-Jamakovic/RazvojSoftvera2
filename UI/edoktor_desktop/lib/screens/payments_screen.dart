import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../providers/providers.dart';
import '../services/report_pdf.dart';
import '../utils/labels.dart';
import '../utils/validators.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  static const _pageSize = 20;
  static final _money = NumberFormat.currency(symbol: '€', decimalDigits: 2);
  static final _dateTime = DateFormat('dd.MM.yyyy HH:mm');
  static final _date = DateFormat('dd.MM.yyyy');

  final _search = TextEditingController();
  String? _status;
  DateTimeRange? _range;
  int _page = 0;

  late Future<(PagedList<Payment>, PaymentSummary)> _f;

  @override
  void initState() { super.initState(); _refresh(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  // The range end is inclusive in the UI, so the query runs up to the start of the next day.
  DateTime? get _to => _range == null ? null : DateTime(_range!.end.year, _range!.end.month, _range!.end.day + 1);

  void _refresh({bool resetPage = false}) {
    if (resetPage) _page = 0;
    final p = context.read<PaymentProvider>();
    setState(() {
      _f = (
        p.list(search: _search.text, status: _status, from: _range?.start, to: _to, page: _page, pageSize: _pageSize),
        p.summary(search: _search.text, status: _status, from: _range?.start, to: _to),
      ).wait;
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
      helpText: 'Odaberite period',
      saveText: 'Primijeni',
    );
    if (r == null) return;
    setState(() => _range = r);
    _refresh(resetPage: true);
  }

  String get _filterDescription {
    final parts = <String>[
      _range == null ? 'Svi datumi' : 'Period: ${_date.format(_range!.start)} – ${_date.format(_range!.end)}',
      if (_status != null) 'Status: ${paymentStatusLabel(_status!)}',
      if (_search.text.trim().isNotEmpty) 'Pretraga: "${_search.text.trim()}"',
    ];
    return parts.join(' · ');
  }

  /// Loads every matching transaction (page by page, the API caps page size) for the PDF report.
  Future<List<Payment>> _allForReport() async {
    final p = context.read<PaymentProvider>();
    final all = <Payment>[];
    for (var page = 0;; page++) {
      final res = await p.list(search: _search.text, status: _status, from: _range?.start, to: _to, page: page, pageSize: 100);
      all.addAll(res.items);
      if (res.items.length < 100 || all.length >= res.totalCount) break;
    }
    return all;
  }

  Future<void> _exportPdf({required bool print}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final summary = context.read<PaymentProvider>().summary(search: _search.text, status: _status, from: _range?.start, to: _to);
      final (items, s) = await (_allForReport(), summary).wait;
      final bytes = await ReportPdf.payments(items, s, filterDescription: _filterDescription).save();
      if (print) {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'finansijski-izvjestaj.pdf');
      } else {
        await Printing.sharePdf(bytes: bytes, filename: 'finansijski-izvjestaj.pdf');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Izvještaj nije moguće generisati: $e')));
    }
  }

  Future<void> _refund(Payment p) async {
    final formKey = GlobalKey<FormState>();
    final reason = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Row(children: [
        const Expanded(child: Text('Povrat sredstava')),
        IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: () => Navigator.pop(c, false)),
      ]),
      content: SizedBox(width: 420, child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Vratiti ${_money.format(p.amount)} pacijentu ${p.patientName ?? ''} putem PayPal-a? Ova akcija je nepovratna.'),
        const SizedBox(height: 12),
        TextFormField(controller: reason, autovalidateMode: AutovalidateMode.onUserInteraction, maxLines: 2,
          decoration: const InputDecoration(labelText: 'Razlog povrata'),
          validator: (v) => Validators.requiredMax(v, 200, 'Razlog povrata')),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Odustani')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(c, true); },
          child: const Text('Izvrši povrat')),
      ],
    ));
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<PaymentProvider>().refund(p.captureId!, reason: reason.text.trim());
      messenger.showSnackBar(SnackBar(content: Text('Povrat od ${_money.format(p.amount)} je uspješno izvršen.')));
      _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  String _refundBlockedReason(Payment p) => switch (p.status) {
        'Refunded' => 'Povrat je već izvršen.',
        'Created' => 'Uplata nije naplaćena.',
        _ => 'Povrat je moguć samo za otkazane termine.',
      };

  Color _statusColor(String s) => switch (s) { 'Captured' => Colors.green, 'Created' => Colors.orange, 'Refunded' => Colors.blueGrey, _ => Colors.grey };

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Plaćanja', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const Spacer(),
        FilledButton.icon(onPressed: () => _exportPdf(print: false), icon: const Icon(Icons.download), label: const Text('Preuzmi PDF')),
        const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: () => _exportPdf(print: true), icon: const Icon(Icons.print), label: const Text('Štampaj')),
      ]),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 280, child: TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: 'Pretraga (pacijent ili ljekar)',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), tooltip: 'Očisti', onPressed: () { _search.clear(); _refresh(resetPage: true); }),
            isDense: true, border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _refresh(resetPage: true),
        )),
        SizedBox(width: 200, child: DropdownButtonFormField<String?>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: null, child: Text('Svi statusi')),
            DropdownMenuItem(value: 'Captured', child: Text('Naplaćeno')),
            DropdownMenuItem(value: 'Created', child: Text('Na čekanju')),
            DropdownMenuItem(value: 'Refunded', child: Text('Vraćeno')),
          ],
          onChanged: (v) { setState(() => _status = v); _refresh(resetPage: true); },
        )),
        OutlinedButton.icon(
          onPressed: _pickRange,
          icon: const Icon(Icons.date_range),
          label: Text(_range == null ? 'Odaberi period' : '${_date.format(_range!.start)} – ${_date.format(_range!.end)}'),
        ),
        if (_range != null)
          IconButton(icon: const Icon(Icons.clear), tooltip: 'Ukloni period', onPressed: () { setState(() => _range = null); _refresh(resetPage: true); }),
        FilledButton.icon(onPressed: () => _refresh(resetPage: true), icon: const Icon(Icons.search), label: const Text('Traži')),
      ]),
      const SizedBox(height: 16),
      Expanded(child: FutureBuilder<(PagedList<Payment>, PaymentSummary)>(future: _f, builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('Greška pri učitavanju plaćanja: ${s.error}', style: const TextStyle(color: Colors.red)));
        final (page, summary) = s.data!;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 16, runSpacing: 16, children: [
            _stat('Ukupno naplaćeno', _money.format(summary.totalCaptured), Icons.payments),
            _stat('Vraćeno (refund)', _money.format(summary.totalRefunded), Icons.undo),
            _stat('Neto prihod', _money.format(summary.netRevenue), Icons.account_balance_wallet),
            _stat('Transakcije', '${summary.capturedCount} naplaćeno · ${summary.refundedCount} vraćeno · ${summary.pendingCount} na čekanju', Icons.receipt_long, wide: true),
          ]),
          const SizedBox(height: 16),
          Expanded(child: Card(child: page.items.isEmpty
              ? const Center(child: Text('Nema transakcija za odabrane filtere.'))
              : SingleChildScrollView(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [
                  DataColumn(label: Text('Datum uplate')),
                  DataColumn(label: Text('Pacijent')),
                  DataColumn(label: Text('Ljekar')),
                  DataColumn(label: Text('Termin')),
                  DataColumn(label: Text('Iznos'), numeric: true),
                  DataColumn(label: Text('Status uplate')),
                  DataColumn(label: Text('Status termina')),
                  DataColumn(label: Text('Akcije')),
                ], rows: page.items.map((p) => DataRow(cells: [
                  DataCell(Text(_dateTime.format(p.createdAt))),
                  DataCell(Text(p.patientName ?? '-')),
                  DataCell(Text(p.doctorName ?? '-')),
                  DataCell(Text(p.appointmentStart == null ? '-' : _dateTime.format(p.appointmentStart!))),
                  DataCell(Text(_money.format(p.amount))),
                  DataCell(Chip(
                    label: Text(paymentStatusLabel(p.status), style: TextStyle(color: _statusColor(p.status), fontWeight: FontWeight.w600)),
                    backgroundColor: _statusColor(p.status).withValues(alpha: 0.1),
                    side: BorderSide.none,
                  )),
                  DataCell(Text(appointmentStatusLabel(p.appointmentStatus))),
                  DataCell(Tooltip(
                    message: p.canRefund ? 'Vrati sredstva pacijentu' : _refundBlockedReason(p),
                    child: TextButton.icon(
                      onPressed: p.canRefund ? () => _refund(p) : null,
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Povrat'),
                    ),
                  )),
                ])).toList()))))),
          const SizedBox(height: 8),
          _pager(page.totalCount),
        ]);
      })),
    ]));
  }

  Widget _pager(int total) {
    final first = total == 0 ? 0 : _page * _pageSize + 1;
    final last = ((_page + 1) * _pageSize).clamp(0, total);
    final hasNext = last < total;
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Text('Prikazano $first–$last od $total'),
      const SizedBox(width: 12),
      IconButton(icon: const Icon(Icons.chevron_left), tooltip: 'Prethodna strana',
        onPressed: _page > 0 ? () { _page--; _refresh(); } : null),
      IconButton(icon: const Icon(Icons.chevron_right), tooltip: 'Sljedeća strana',
        onPressed: hasNext ? () { _page++; _refresh(); } : null),
    ]);
  }

  Widget _stat(String label, String value, IconData icon, {bool wide = false}) => Container(
    width: wide ? 420 : 220, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: const Color(0xFF0D47A1)), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.grey))]),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: wide ? 15 : 22, fontWeight: FontWeight.bold)),
    ]),
  );
}
