import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../models/medical_record.dart';
import '../providers/providers.dart';
import '../utils/labels.dart';
import '../utils/validators.dart';

final _fmt = DateFormat('dd.MM.yyyy HH:mm');

/// Add (pick one of [appointments]) or edit ([entry]) a visit in the medical record.
/// Saves through the API inside "Sačuvaj"; returns true when saved.
Future<bool> showMedicalEntryForm(BuildContext context, {List<Appointment> appointments = const [], RecordEntry? entry}) async {
  final formKey = GlobalKey<FormState>();
  final diagnosis = TextEditingController(text: entry?.diagnosis ?? '');
  final therapy = TextEditingController(text: entry?.therapy ?? '');
  final notes = TextEditingController(text: entry?.notes ?? '');
  final provider = context.read<MedicalRecordProvider>();
  int? appointmentId = entry?.appointmentId ?? (appointments.length == 1 ? appointments.first.id : null);
  var saving = false;
  String? error;

  String? optional(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
    title: Row(children: [
      Expanded(child: Text(entry == null ? 'Nova posjeta' : 'Uredi posjetu')),
      IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: saving ? null : () => Navigator.pop(ctx, false)),
    ]),
    content: SizedBox(width: 520, child: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (entry == null)
        DropdownButtonFormField<int>(
          initialValue: appointmentId,
          isExpanded: true,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Termin'),
          items: appointments.map((a) => DropdownMenuItem(value: a.id,
              child: Text('${_fmt.format(a.startUtc)} • ${a.isOnline ? 'Online' : 'Uživo'} • ${appointmentStatusLabel(a.status)}'))).toList(),
          onChanged: saving ? null : (v) => setLocal(() => appointmentId = v),
          validator: (v) => v == null ? 'Odaberite termin.' : null)
      else
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Termin'),
          child: Text(_fmt.format(entry.appointmentDate))),
      const SizedBox(height: 8),
      TextFormField(controller: diagnosis, maxLines: 3, autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: const InputDecoration(labelText: 'Dijagnoza'),
        validator: (v) => Validators.requiredMax(v, 2000, 'Dijagnoza')),
      const SizedBox(height: 8),
      TextFormField(controller: therapy, maxLines: 3, autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: const InputDecoration(labelText: 'Terapija (opciono)'),
        validator: (v) => Validators.maxLen(v, 4000, 'Terapija')),
      const SizedBox(height: 8),
      TextFormField(controller: notes, maxLines: 3, autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: const InputDecoration(labelText: 'Napomene (opciono)'),
        validator: (v) => Validators.maxLen(v, 4000, 'Napomene')),
      if (error != null)
        Padding(padding: const EdgeInsets.only(top: 12),
          child: Align(alignment: Alignment.centerLeft, child: Text(error!, style: const TextStyle(color: Colors.red)))),
    ])))),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.pop(ctx, false), child: const Text('Odustani')),
      FilledButton(
        onPressed: saving ? null : () async {
          if (!formKey.currentState!.validate()) return;
          setLocal(() { saving = true; error = null; });
          try {
            if (entry == null) {
              await provider.addEntry(appointmentId: appointmentId!, diagnosis: diagnosis.text.trim(), therapy: optional(therapy), notes: optional(notes));
            } else {
              await provider.updateEntry(entry.id, appointmentId: entry.appointmentId, diagnosis: diagnosis.text.trim(), therapy: optional(therapy), notes: optional(notes));
            }
            if (ctx.mounted) Navigator.pop(ctx, true);
          } catch (e) {
            if (ctx.mounted) setLocal(() { saving = false; error = '$e'; });
          }
        },
        child: saving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Sačuvaj')),
    ],
  )));
  return ok == true;
}
