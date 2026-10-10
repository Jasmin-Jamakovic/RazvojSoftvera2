import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/appointment.dart';
import '../providers/appointment_provider.dart';
import '../theme/app_theme.dart';
import '../utils/confirm.dart';
import '../widgets/ui.dart';
import 'paypal_checkout_screen.dart';
import 'video_call_screen.dart';

class MyAppointmentsTab extends StatefulWidget {
  const MyAppointmentsTab({super.key});
  @override
  State<MyAppointmentsTab> createState() => _MyAppointmentsTabState();
}

class _MyAppointmentsTabState extends State<MyAppointmentsTab> {
  late Future<List<Appointment>> _f;
  bool _showPast = false;

  @override
  void initState() {
    super.initState();
    _f = context.read<AppointmentProvider>().mine();
  }

  Future<void> _refresh() async { setState(() { _f = context.read<AppointmentProvider>().mine(); }); }

  Future<void> _cancel(Appointment a) async {
    final ok = await confirmDialog(
      context,
      title: 'Otkazivanje termina',
      message: 'Da li ste sigurni da želite otkazati termin kod ${a.doctorName ?? "ljekara"}? Ova akcija je nepovratna.',
      confirmLabel: 'Otkaži termin',
      cancelLabel: 'Nazad',
      danger: true,
    );
    if (!ok || !mounted) return;
    try { await context.read<AppointmentProvider>().cancel(a.id); _refresh(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> _pay(Appointment a) async {
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PaypalCheckoutScreen(appointmentId: a.id, price: a.price)),
    );
    if (paid == true) _refresh();
  }

  Future<void> _join(Appointment a) async {
    try {
      final res = await context.read<AppointmentProvider>().roomFor(a.id);
      final url = res['joinUrl'] as String?;
      if (url == null || !mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => VideoCallScreen(joinUrl: url, doctorName: a.doctorName ?? 'ljekar'),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  static bool _isUpcoming(Appointment a, DateTime now) =>
      (a.status == 'Pending' || a.status == 'Confirmed') && a.endUtc.isAfter(now);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Text('Moji termini', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.ink)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _Segmented(
            labels: const ['Nadolazeći', 'Prošli'],
            selected: _showPast ? 1 : 0,
            onSelect: (i) => setState(() => _showPast = i == 1),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<Appointment>>(
              future: _f,
              builder: (c, s) {
                if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (s.hasError) return Center(child: Text('${s.error}'));
                final now = DateTime.now();
                final all = s.data ?? [];
                final list = all.where((a) => _isUpcoming(a, now) != _showPast).toList()
                  ..sort((a, b) => _showPast ? b.startUtc.compareTo(a.startUtc) : a.startUtc.compareTo(b.startUtc));
                if (list.isEmpty) {
                  return ListView(children: [
                    const SizedBox(height: 80),
                    EmptyState(
                      icon: _showPast ? Icons.history : Icons.event_available_outlined,
                      message: _showPast ? 'Nemate prošlih termina.' : 'Nemate nadolazećih termina.',
                    ),
                  ]);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (c, i) => _AppointmentCard(
                    appointment: list[i],
                    featured: !_showPast && i == 0,
                    onPay: _pay,
                    onJoin: _join,
                    onCancel: _cancel,
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final bool featured;
  final ValueChanged<Appointment> onPay;
  final ValueChanged<Appointment> onJoin;
  final ValueChanged<Appointment> onCancel;

  const _AppointmentCard({
    required this.appointment,
    required this.featured,
    required this.onPay,
    required this.onJoin,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final canCancel = a.status == 'Pending' || (a.status == 'Confirmed' && a.startUtc.difference(DateTime.now()).inHours >= 24);
    final canJoin = a.status == 'Confirmed' && a.isOnline && a.startUtc.difference(DateTime.now()).inMinutes <= 30 && a.endUtc.isAfter(DateTime.now());
    final canPay = a.status == 'Pending' && !a.isPaid;
    final fg = featured ? Colors.white : AppColors.ink;
    final sub = featured ? Colors.white.withValues(alpha: 0.75) : AppColors.muted;

    final actions = <Widget>[
      if (canPay)
        _ActionButton(
          label: 'Plati ${a.price.toStringAsFixed(0)} €',
          icon: Icons.payment,
          style: featured ? _ActionStyle.white : _ActionStyle.primary,
          onTap: () => onPay(a),
        ),
      if (canJoin)
        _ActionButton(
          label: 'Uđi u poziv',
          icon: Icons.videocam,
          style: featured ? _ActionStyle.white : _ActionStyle.primary,
          onTap: () => onJoin(a),
        ),
      if (canCancel)
        _ActionButton(label: 'Otkaži', style: featured ? _ActionStyle.glass : _ActionStyle.soft, onTap: () => onCancel(a)),
    ];

    return AppCard(
      gradient: featured ? AppColors.gradient : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: featured ? Colors.white.withValues(alpha: 0.16) : AppColors.tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              Text('${a.startUtc.day}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.1, color: featured ? Colors.white : AppColors.primary)),
              Text(bsMonthsShort[a.startUtc.month - 1].toUpperCase(),
                  style: TextStyle(fontSize: 10, letterSpacing: 0.6, color: featured ? Colors.white70 : AppColors.primary)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.doctorName ?? '', overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: fg)),
              const SizedBox(height: 4),
              DefaultTextStyle(
                style: TextStyle(fontSize: 12, color: sub),
                child: Row(children: [
                  Icon(Icons.schedule, size: 14, color: sub),
                  const SizedBox(width: 3),
                  Text('${bsDaysShort[a.startUtc.weekday - 1]} ${hhmm(a.startUtc)}'),
                  const SizedBox(width: 12),
                  Icon(a.isOnline ? Icons.videocam_outlined : Icons.local_hospital_outlined, size: 14, color: sub),
                  const SizedBox(width: 3),
                  Text(a.typeLabel),
                ]),
              ),
            ]),
          ),
          StatusPill(a.status, isPaid: a.isPaid, onGradient: featured),
        ]),
        if (featured || a.isPaid)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(spacing: 8, children: [
              if (featured)
                Pill(relativeFromNow(a.startUtc), icon: Icons.schedule, fg: Colors.white, bg: Colors.white.withValues(alpha: 0.16)),
              if (a.isPaid)
                Pill('Plaćeno',
                    icon: Icons.check,
                    fg: featured ? Colors.white : AppColors.primary,
                    bg: featured ? Colors.white.withValues(alpha: 0.16) : AppColors.tint),
            ]),
          ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: featured ? Colors.white24 : AppColors.line),
          const SizedBox(height: 12),
          Row(children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: actions[i]),
            ],
          ]),
        ],
      ]),
    );
  }
}

enum _ActionStyle { primary, soft, white, glass }

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final _ActionStyle style;
  final VoidCallback onTap;

  const _ActionButton({required this.label, this.icon, required this.style, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (style) {
      _ActionStyle.primary => (AppColors.primary, Colors.white),
      _ActionStyle.soft => (AppColors.tint, AppColors.primary),
      _ActionStyle.white => (Colors.white, AppColors.primary),
      _ActionStyle.glass => (Colors.white.withValues(alpha: 0.16), Colors.white),
    };
    final br = BorderRadius.circular(10);
    return Material(
      color: bg,
      borderRadius: br,
      child: InkWell(
        borderRadius: br,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13))),
          ]),
        ),
      ),
    );
  }
}

/// Two-option toggle with a sliding white thumb.
class _Segmented extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  const _Segmented({required this.labels, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFDDE7DF), borderRadius: BorderRadius.circular(14)),
      child: Stack(children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment(selected == 0 ? -1 : 1, 0),
          child: FractionallySizedBox(
            widthFactor: 1 / labels.length,
            heightFactor: 1,
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), boxShadow: AppColors.softShadow),
            ),
          ),
        ),
        Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: Center(
                  child: Text(labels[i],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: i == selected ? AppColors.primary : const Color(0xFF5B6476),
                      )),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}
