import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/medical_record.dart';
import '../providers/providers.dart';
import '../utils/validators.dart';

/// Master-details form for an e-prescription: the visit it belongs to (master) and its medication rows (details).
/// Creates a prescription for the visit [entryId], or replaces all rows of [existing]. Returns true when saved.
/// [visitDate] and [diagnosis] describe the visit in the dialog's header.
Future<bool> showPrescriptionForm(BuildContext context, {required int entryId, required DateTime visitDate, String? diagnosis, Prescription? existing}) async {
  final ok = await showDialog<bool>(context: context,
      builder: (_) => _PrescriptionDialog(entryId: entryId, visitDate: visitDate, diagnosis: diagnosis, existing: existing));
  return ok == true;
}

class _ItemRow {
  final medication = TextEditingController();
  final dosage = TextEditingController();
  final frequency = TextEditingController();
  final duration = TextEditingController();

  _ItemRow([PrescriptionItem? i]) {
    medication.text = i?.medication ?? '';
    dosage.text = i?.dosage ?? '';
    frequency.text = i?.frequency ?? '';
    duration.text = i?.duration ?? '';
  }

  static String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  PrescriptionItem toItem() => PrescriptionItem(
      medication: medication.text.trim(), dosage: _opt(dosage), frequency: _opt(frequency), duration: _opt(duration));

  void dispose() {
    medication.dispose();
    dosage.dispose();
    frequency.dispose();
    duration.dispose();
  }
}

class _PrescriptionDialog extends StatefulWidget {
  final int entryId;
  final DateTime visitDate;
  final String? diagnosis;
  final Prescription? existing;
  const _PrescriptionDialog({required this.entryId, required this.visitDate, this.diagnosis, this.existing});

  @override
  State<_PrescriptionDialog> createState() => _PrescriptionDialogState();
}

class _PrescriptionDialogState extends State<_PrescriptionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<_ItemRow> _rows;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final items = widget.existing?.items ?? const <PrescriptionItem>[];
    _rows = items.isEmpty ? [_ItemRow()] : items.map(_ItemRow.new).toList();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addRow() => setState(() => _rows.add(_ItemRow()));

  void _removeRow(int i) => setState(() => _rows.removeAt(i).dispose());

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rows.isEmpty) {
      setState(() => _error = 'Recept mora imati barem jedan lijek.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final provider = context.read<MedicalRecordProvider>();
    final items = _rows.map((r) => r.toItem()).toList();
    try {
      if (widget.existing == null) {
        await provider.addPrescription(entryId: widget.entryId, items: items);
      } else {
        await provider.updatePrescription(widget.existing!.id, entryId: widget.entryId, items: items);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = '$e'; });
    }
  }

  Widget _field(TextEditingController c, String label, int max, {bool required = false}) => TextFormField(
        controller: c,
        enabled: !_saving,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(labelText: required ? label : '$label (opciono)', isDense: true),
        validator: (v) => required ? Validators.requiredMax(v, max, label) : Validators.maxLen(v, max, label),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        Expanded(child: Text(widget.existing == null ? 'Novi recept' : 'Uredi recept')),
        IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: _saving ? null : () => Navigator.pop(context, false)),
      ]),
      content: SizedBox(width: 860, child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Master: the visit the prescription is issued on.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF1F6F2), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Posjeta ${DateFormat('dd.MM.yyyy HH:mm').format(widget.visitDate)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('Dijagnoza: ${widget.diagnosis ?? '-'}', maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Text('Lijekovi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Spacer(),
          TextButton.icon(onPressed: _saving ? null : _addRow, icon: const Icon(Icons.add), label: const Text('Dodaj lijek')),
        ]),
        // Details: one row per medication.
        Flexible(child: SingleChildScrollView(child: Column(children: [
          for (var i = 0; i < _rows.length; i++)
            Padding(
              key: ObjectKey(_rows[i]),
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 14, right: 8), child: Text('${i + 1}.')),
                Expanded(flex: 3, child: _field(_rows[i].medication, 'Lijek', 200, required: true)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _field(_rows[i].dosage, 'Doza', 100)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _field(_rows[i].frequency, 'Učestalost', 100)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _field(_rows[i].duration, 'Trajanje', 100)),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  tooltip: _rows.length == 1 ? 'Recept mora imati barem jedan lijek.' : 'Ukloni lijek',
                  onPressed: _saving || _rows.length == 1 ? null : () => _removeRow(i),
                ),
              ]),
            ),
        ]))),
        if (_error != null)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
      ]))),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Odustani')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Sačuvaj')),
      ],
    );
  }
}
