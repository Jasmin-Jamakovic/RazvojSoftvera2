import 'package:flutter/material.dart';

/// Shows a yes/no confirmation dialog for irreversible actions (booking, cancel, pay).
/// Returns true only if the user explicitly confirms.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Potvrdi',
  String cancelLabel = 'Odustani',
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(cancelLabel)),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Colors.red) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}
