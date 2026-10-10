import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/dashboard.dart';
import '../models/entities.dart';
import '../utils/labels.dart';

/// Builds the two downloadable/printable PDF reports for the admin app.
class ReportPdf {
  static final _money = NumberFormat.currency(symbol: 'EUR ', decimalDigits: 2);
  static final _date = DateFormat('dd.MM.yyyy. HH:mm');

  static pw.Widget _header(String title, {String? subtitle}) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('eDoktor', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0D47A1))),
              pw.Text('Generisano: ${_date.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          if (subtitle != null) pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Divider(color: PdfColors.grey400),
        ],
      );

  static pw.Widget _footer(pw.Context ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Strana ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      );

  /// Report 1 — doctor performance for a period: exams, ratings and revenue per doctor, with summary KPIs.
  static pw.Document doctorPerformance(DoctorReport r, {required String filterDescription}) {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      footer: _footer,
      build: (ctx) => [
        _header('Izvještaj o učinku ljekara', subtitle: filterDescription),
        pw.SizedBox(height: 8),
        pw.Wrap(spacing: 16, runSpacing: 8, children: [
          _kpi('Ukupno pregleda', '${r.totalExams}'),
          _kpi('Prihod', _money.format(r.totalRevenue)),
          _kpi('Najtraženija specijalizacija', r.topSpecialization ?? '-'),
          _kpi('Najbolje ocijenjen ljekar', r.topDoctor == null ? '-' : '${r.topDoctor} (${r.topDoctorRating.toStringAsFixed(1)})'),
        ]),
        pw.SizedBox(height: 16),
        pw.Text('Pregled po ljekaru', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0D47A1)),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft, 2: pw.Alignment.center, 3: pw.Alignment.center, 4: pw.Alignment.centerRight},
          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F5F9)),
          headers: ['Ljekar', 'Specijalizacija', 'Broj pregleda', 'Prosječna ocjena', 'Prihod'],
          data: r.rows
              .map((x) => [x.doctorName, x.specialization ?? '-', '${x.appointmentCount}', x.averageRating == 0 ? '-' : x.averageRating.toStringAsFixed(1), _money.format(x.revenue)])
              .toList(),
        ),
        pw.Divider(color: PdfColors.grey400),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('UKUPNO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.Text('Pregleda: ${r.totalExams}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.Text('Prihod: ${_money.format(r.totalRevenue)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        ]),
      ],
    ));
    return doc;
  }

  /// Report 2 — appointments list over the current data set, with status filter info
  /// and a per-status summary.
  static pw.Document appointments(List<Appointment> items, {required String filterDescription}) {
    final doc = pw.Document();
    final byStatus = <String, int>{};
    var totalRevenue = 0.0;
    for (final a in items) {
      byStatus[a.status] = (byStatus[a.status] ?? 0) + 1;
      totalRevenue += a.price;
    }
    final sub = '$filterDescription · ${items.length} termina';

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      footer: _footer,
      build: (ctx) => [
        _header('Izvještaj o terminima', subtitle: sub),
        pw.SizedBox(height: 8),
        pw.Wrap(spacing: 16, runSpacing: 8, children: [
          _kpi('Ukupno termina', '${items.length}'),
          _kpi('Ukupan prihod', _money.format(totalRevenue)),
          for (final e in byStatus.entries) _kpi(appointmentStatusLabel(e.key), '${e.value}'),
        ]),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0D47A1)),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft, 2: pw.Alignment.centerLeft, 3: pw.Alignment.center, 4: pw.Alignment.center, 5: pw.Alignment.centerRight},
          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F5F9)),
          headers: ['Datum i vrijeme', 'Pacijent', 'Ljekar', 'Tip', 'Status', 'Cijena'],
          data: items
              .map((a) => [
                    _date.format(a.startUtc.toLocal()),
                    a.patientName ?? '-',
                    a.doctorName ?? '-',
                    a.type == 1 ? 'Online' : 'U ordinaciji',
                    appointmentStatusLabel(a.status),
                    _money.format(a.price),
                  ])
              .toList(),
        ),
      ],
    ));
    return doc;
  }

  /// Report 3 — financial report: PayPal transactions in the selected period with totals.
  static pw.Document payments(List<Payment> items, PaymentSummary summary, {required String filterDescription}) {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      footer: _footer,
      build: (ctx) => [
        _header('Finansijski izvještaj', subtitle: '$filterDescription · ${items.length} transakcija'),
        pw.SizedBox(height: 8),
        pw.Wrap(spacing: 16, runSpacing: 8, children: [
          _kpi('Ukupno naplaćeno', _money.format(summary.totalCaptured)),
          _kpi('Vraćeno (refund)', _money.format(summary.totalRefunded)),
          _kpi('Neto prihod', _money.format(summary.netRevenue)),
          _kpi('Naplaćene uplate', '${summary.capturedCount}'),
          _kpi('Vraćene uplate', '${summary.refundedCount}'),
          _kpi('Na čekanju', '${summary.pendingCount}'),
        ]),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0D47A1)),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft, 2: pw.Alignment.centerLeft, 3: pw.Alignment.center, 4: pw.Alignment.centerRight},
          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F5F9)),
          headers: ['Datum uplate', 'Pacijent', 'Ljekar', 'Status', 'Iznos'],
          data: items
              .map((p) => [
                    _date.format(p.createdAt),
                    p.patientName ?? '-',
                    p.doctorName ?? '-',
                    paymentStatusLabel(p.status),
                    _money.format(p.amount),
                  ])
              .toList(),
        ),
      ],
    ));
    return doc;
  }

  static pw.Widget _kpi(String label, String value) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F5F9), borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ]),
      );
}
