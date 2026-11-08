import 'package:flutter/material.dart';
import '../utils/validators.dart';

/// Asks the admin to confirm a PayPal refund and enter a reason.
/// Returns the trimmed reason, or null if the dialog was dismissed.
Future<String?> showRefundReasonDialog(BuildContext context, {required String message}) async {
  final formKey = GlobalKey<FormState>();
  final reason = TextEditingController();
  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    title: Row(children: [
      const Expanded(child: Text('Povrat sredstava')),
      IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: () => Navigator.pop(c, false)),
    ]),
    content: SizedBox(width: 420, child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(message),
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
  final text = reason.text.trim();
  reason.dispose();
  return ok == true ? text : null;
}
