import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/medical_record.dart';

/// Builds downloadable PDFs from the patient's medical record (e-prescription, lab result, visit report).
class RecordPdf {
  static final _date = DateFormat('dd.MM.yyyy.');
  static final _dateTime = DateFormat('dd.MM.yyyy. HH:mm');
  static const _green = PdfColor.fromInt(0xFF2E7D32);

  static pw.ThemeData? _theme;

  /// Embedded Roboto so Bosnian letters (č, ć, š, ž, đ) render; the built-in PDF fonts lack them.
  static Future<pw.ThemeData> _loadTheme() async {
    return _theme ??= pw.ThemeData.withFont(
      base: pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf')),
      bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf')),
    );
  }

  /// Opens the system share/save sheet for the PDF (on Android: save to Files, send, print…).
  static Future<void> share(Future<Uint8List> pdf, String fileName) async {
    await Printing.sharePdf(bytes: await pdf, filename: fileName);
  }

  static Future<Uint8List> _build(String title, List<pw.Widget> Function() body) async {
    final doc = pw.Document(theme: await _loadTheme(), title: title, author: 'eDoktor');
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('eDoktor', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _green)),
          pw.Text('Generisano: ${_dateTime.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ]),
        pw.SizedBox(height: 4),
        pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 6),
      ]),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Strana ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ),
      build: (_) => body(),
    ));
    return doc.save();
  }

  static pw.Widget _patientBox(MedicalRecord r) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFFF0F9F1), borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          _field('Pacijent', r.patientName ?? '-'),
          _field('Datum rođenja', r.dateOfBirth == null ? '-' : _date.format(r.dateOfBirth!)),
          _field('Krvna grupa', r.bloodType ?? '-'),
        ]),
      );

  static pw.Widget _field(String label, String value) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ]);

  static pw.Widget _section(String title, String? text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _green)),
          pw.SizedBox(height: 3),
          pw.Text((text == null || text.trim().isEmpty) ? '-' : text, style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
        ]),
      );

  static pw.Widget _itemsTable(Prescription p) => pw.TableHelper.fromTextArray(
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
        headerDecoration: const pw.BoxDecoration(color: _green),
        cellStyle: const pw.TextStyle(fontSize: 10),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F5F3)),
        headers: ['Lijek', 'Doza', 'Učestalost', 'Trajanje'],
        data: p.items.map((i) => [i.medication, i.dosage ?? '-', i.frequency ?? '-', i.duration ?? '-']).toList(),
      );

  static String prescriptionNumber(Prescription p) => 'ERX-${p.id.toString().padLeft(6, '0')}';

  static Future<Uint8List> prescription(MedicalRecord r, Prescription p) => _build('Elektronski recept', () => [
        _patientBox(r),
        pw.SizedBox(height: 12),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          _field('Broj recepta', prescriptionNumber(p)),
          _field('Datum izdavanja', _date.format(p.issuedAt)),
          _field('Ljekar', p.doctorName == null ? '-' : 'dr. ${p.doctorName}'),
        ]),
        pw.SizedBox(height: 16),
        _itemsTable(p),
        pw.SizedBox(height: 24),
        pw.Text('Recept predočite u apoteci zajedno sa ličnim dokumentom.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ]);

  static Future<Uint8List> labResult(MedicalRecord r, LabResult l) => _build('Laboratorijski nalaz', () => [
        _patientBox(r),
        pw.SizedBox(height: 12),
        _field('Datum nalaza', _date.format(l.createdAt)),
        _section('Naziv pretrage', l.title),
        _section('Rezultat i napomene', l.notes),
      ]);

  static Future<Uint8List> visit(MedicalRecord r, MedicalRecordEntry e) => _build('Izvještaj ljekara', () => [
        _patientBox(r),
        pw.SizedBox(height: 12),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          _field('Datum pregleda', _dateTime.format(e.appointmentDate)),
          _field('Ljekar', e.doctorName == null ? '-' : 'dr. ${e.doctorName}'),
          _field('Specijalizacija', e.specialization ?? '-'),
        ]),
        _section('Dijagnoza', e.diagnosis),
        _section('Terapija', e.therapy),
        _section('Napomene', e.notes),
        if (e.prescription != null) ...[
          pw.SizedBox(height: 16),
          pw.Text('Propisani lijekovi (${prescriptionNumber(e.prescription!)})',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _green)),
          pw.SizedBox(height: 6),
          _itemsTable(e.prescription!),
        ],
      ]);
}
