import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medical_record.dart';
import '../providers/providers.dart';
import '../utils/validators.dart';

/// Add or edit ([result]) a lab result in [patientId]'s record. Returns true when saved.
Future<bool> showLabResultForm(BuildContext context, {required int patientId, LabResult? result}) async {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController(text: result?.title ?? '');
  final notes = TextEditingController(text: result?.notes ?? '');
  final provider = context.read<MedicalRecordProvider>();
  var saving = false;
  String? error;

  final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
    title: Row(children: [
      Expanded(child: Text(result == null ? 'Novi nalaz' : 'Uredi nalaz')),
      IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: saving ? null : () => Navigator.pop(ctx, false)),
    ]),
    content: SizedBox(width: 480, child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: title, autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: const InputDecoration(labelText: 'Naziv nalaza', hintText: 'npr. Kompletna krvna slika'),
        validator: (v) => Validators.requiredMax(v, 200, 'Naziv nalaza')),
      const SizedBox(height: 8),
      TextFormField(controller: notes, maxLines: 5, autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: const InputDecoration(labelText: 'Rezultati / napomene (opciono)'),
        validator: (v) => Validators.maxLen(v, 2000, 'Napomene')),
      if (error != null)
        Padding(padding: const EdgeInsets.only(top: 12),
          child: Align(alignment: Alignment.centerLeft, child: Text(error!, style: const TextStyle(color: Colors.red)))),
    ]))),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.pop(ctx, false), child: const Text('Odustani')),
      FilledButton(
        onPressed: saving ? null : () async {
          if (!formKey.currentState!.validate()) return;
          setLocal(() { saving = true; error = null; });
          final n = notes.text.trim().isEmpty ? null : notes.text.trim();
          try {
            if (result == null) {
              await provider.addLabResult(patientId: patientId, title: title.text.trim(), notes: n);
            } else {
              await provider.updateLabResult(result.id, patientId: patientId, title: title.text.trim(), notes: n);
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
