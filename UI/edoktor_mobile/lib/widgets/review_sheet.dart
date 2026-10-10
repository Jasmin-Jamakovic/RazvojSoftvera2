import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/appointment.dart';
import '../providers/appointment_provider.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import 'ui.dart';

/// Bottom sheet for rating a completed appointment. Pops with true once the review is saved.
class ReviewSheet extends StatefulWidget {
  final Appointment appointment;
  const ReviewSheet({super.key, required this.appointment});

  static Future<bool> show(BuildContext context, Appointment a) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ReviewSheet(appointment: a),
    );
    return saved == true;
  }

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  static const _labels = ['Loše', 'Ispod očekivanja', 'Dobro', 'Vrlo dobro', 'Odlično'];

  final _formKey = GlobalKey<FormState>();
  final _comment = TextEditingController();
  int _rating = 0;
  bool _showRatingError = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() { _comment.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _showRatingError = _rating == 0);
    if (!valid || _rating == 0) return;
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AppointmentProvider>().review(widget.appointment.id, rating: _rating, comment: _comment.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: Text('Ocijenite pregled', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: () => Navigator.pop(context, false)),
          ]),
          Text('${a.doctorName ?? ''} · ${dayLabel(a.startUtc)} u ${hhmm(a.startUtc)}', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                iconSize: 40,
                tooltip: '$i/5 – ${_labels[i - 1]}',
                onPressed: () => setState(() { _rating = i; _showRatingError = false; }),
                icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.star),
              ),
          ]),
          Center(
            child: Text(_rating == 0 ? 'Dodirnite zvjezdicu' : _labels[_rating - 1],
                style: TextStyle(color: _rating == 0 ? AppColors.muted : AppColors.ink, fontWeight: FontWeight.w600)),
          ),
          if (_showRatingError)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Center(child: Text('Odaberite ocjenu od 1 do 5 zvjezdica.', style: TextStyle(color: Color(0xFFC62828), fontSize: 12))),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _comment,
            maxLines: 4,
            maxLength: 1000,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: const InputDecoration(labelText: 'Komentar (opciono)', alignLabelWithHint: true),
            validator: (v) => Validators.maxLen(v, 1000, 'Komentar'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Color(0xFFC62828), fontSize: 13)),
          ],
          const SizedBox(height: 12),
          GradientButton(label: 'Pošalji ocjenu', icon: Icons.send_outlined, busy: _busy, onPressed: _submit),
        ]),
      ),
    );
  }
}
