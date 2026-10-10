import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/payment.dart';
import '../providers/payment_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// The patient's PayPal payments and refunds with dates, amounts and statuses.
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});
  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  static const _pageSize = 20;
  static final _dateTime = DateFormat('dd.MM.yyyy. HH:mm');
  static final _money = NumberFormat.currency(locale: 'en', symbol: '€', decimalDigits: 2);

  final List<Payment> _items = [];
  int _total = 0;
  int _page = 0;
  PaymentSummary? _summary;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() { _loading = true; _error = null; });
    try {
      final p = context.read<PaymentProvider>();
      final (page, summary) = await (p.history(pageSize: _pageSize), p.summary()).wait;
      if (!mounted) return;
      setState(() {
        _items..clear()..addAll(page.$1);
        _total = page.$2;
        _page = 0;
        _summary = summary;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final (items, total) = await context.read<PaymentProvider>().history(page: _page + 1, pageSize: _pageSize);
      if (!mounted) return;
      setState(() { _items.addAll(items); _total = total; _page++; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historija plaćanja')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [EmptyState(icon: Icons.error_outline, message: 'Uplate nije moguće učitati: $_error')])
                : ListView(padding: const EdgeInsets.all(16), children: [
                    if (_summary != null) _summaryCard(_summary!),
                    const SizedBox(height: 16),
                    if (_items.isEmpty)
                      const EmptyState(icon: Icons.receipt_long_outlined, message: 'Još nemate nijednu uplatu.')
                    else ...[
                      for (final p in _items) Padding(padding: const EdgeInsets.only(bottom: 10), child: _paymentCard(p)),
                      if (_items.length < _total)
                        Center(
                          child: _loadingMore
                              ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                              : TextButton(onPressed: _loadMore, child: Text('Učitaj još (${_total - _items.length})')),
                        ),
                    ],
                  ]),
      ),
    );
  }

  Widget _summaryCard(PaymentSummary s) => AppCard(
        gradient: AppColors.gradient,
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          _summaryValue('Plaćeno', _money.format(s.totalCaptured)),
          _summaryValue('Vraćeno', _money.format(s.totalRefunded)),
          _summaryValue('Ukupno', _money.format(s.netRevenue)),
        ]),
      );

  Widget _summaryValue(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _paymentCard(Payment p) {
    final (label, fg, bg, icon) = switch (p.status) {
      'Captured' => ('Plaćeno', AppColors.primary, AppColors.tint, Icons.check_circle_outline),
      'Refunded' => ('Vraćeno', const Color(0xFF1565C0), const Color(0xFFE3F0FD), Icons.undo),
      _ => ('Na čekanju', const Color(0xFFEF6C00), const Color(0xFFFFF2E0), Icons.hourglass_empty),
    };
    final refunded = p.status == 'Refunded';
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconSquare(icon, size: 38, iconSize: 19, color: fg, background: bg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.doctorName == null ? 'Pregled' : 'Pregled · dr. ${p.doctorName}',
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (p.appointmentStart != null)
                Text('Termin: ${_dateTime.format(p.appointmentStart!)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${refunded ? '+' : '−'}${_money.format(p.amount)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: refunded ? const Color(0xFF1565C0) : AppColors.ink)),
            const SizedBox(height: 4),
            Pill(label, fg: fg, bg: bg),
          ]),
        ]),
        const Divider(height: 20, color: AppColors.line),
        _dateRow('Plaćanje kreirano', p.createdAt),
        if (p.capturedAt != null) _dateRow('Naplaćeno', p.capturedAt!),
        if (p.refundedAt != null) _dateRow('Novac vraćen', p.refundedAt!),
      ]),
    );
  }

  Widget _dateRow(String label, DateTime d) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted))),
          Text(_dateTime.format(d), style: const TextStyle(fontSize: 12)),
        ]),
      );
}
