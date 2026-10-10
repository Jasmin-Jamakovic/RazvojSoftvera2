import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/dashboard.dart';
import '../providers/providers.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardStats> _f;
  @override
  void initState() { super.initState(); _f = context.read<DashboardProvider>().stats(); }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(24), child: FutureBuilder<DashboardStats>(future: _f, builder: (c, s) {
      if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (s.hasError) return Center(child: Text('Greška: ${s.error}'));
      final d = s.data!;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Dashboard', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(spacing: 16, runSpacing: 16, children: [
          _stat('Ukupno ljekara', '${d.totalDoctors}', Icons.medical_services),
          _stat('Pacijenata', '${d.totalPatients}', Icons.people),
          _stat('Termini ukupno', '${d.totalAppointments}', Icons.event_available),
          _stat('Termini danas', '${d.appointmentsToday}', Icons.today),
          _stat('Prihod (mjesec)', '${NumberFormat.currency(symbol: '€', decimalDigits: 0).format(d.revenueThisMonth)}', Icons.euro),
          _stat('Top specijalizacija', d.topSpecialization ?? '-', Icons.star),
          _stat('Najbolji ljekar', '${d.topDoctor ?? "-"} (${d.topDoctorRating.toStringAsFixed(1)})', Icons.emoji_events),
        ]),
        const SizedBox(height: 24),
        const Text('Prihod po ljekaru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(24), child: d.rows.isEmpty ? const Center(child: Text('Nema podataka.')) : BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barGroups: [
            for (int i = 0; i < d.rows.length; i++)
              BarChartGroupData(x: i, barRods: [BarChartRodData(toY: d.rows[i].revenue, color: const Color(0xFF2E7D32), width: 22)])
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 48)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, _) {
              final i = v.toInt(); if (i < 0 || i >= d.rows.length) return const SizedBox();
              return Padding(padding: const EdgeInsets.only(top: 6), child: Text(d.rows[i].doctorName.split(' ').last, style: const TextStyle(fontSize: 10)));
            })),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
        ))))),
      ]);
    }));
  }

  Widget _stat(String label, String value, IconData icon) => Container(
    width: 220, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: const Color(0xFF2E7D32)), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.grey))]),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    ]),
  );
}
