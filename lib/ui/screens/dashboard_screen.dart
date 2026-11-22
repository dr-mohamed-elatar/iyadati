import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../services/local_store.dart';
import 'patients_screen.dart';

/// لوحة اليوم: ملخص العيادة + إجراءات سريعة
class DashboardScreen extends StatelessWidget {
  final void Function(int tab) onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final spec = app.specialty!;
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('أهلًا ${app.profile.doctorName.isEmpty ? 'دكتور' : app.profile.doctorName} 👋',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      Text(spec.name, style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 16),
      FutureBuilder(
        future: Future.wait([
          LocalStore.instance.patientsPage(pageSize: 1),
          LocalStore.instance.appointmentsFor(today),
          LocalStore.instance.daySummary(today),
        ]),
        builder: (ctx, snap) {
          final patients = snap.hasData ? (snap.data![0] as dynamic).total as int : 0;
          final appts = snap.hasData ? (snap.data![1] as List).length : 0;
          final summary = snap.hasData ? (snap.data![2] as ({int visits, double income})) : (visits: 0, income: 0.0);
          return Column(children: [
            Row(children: [
              _StatCard(
                  icon: Icons.people, label: 'المرضى', value: '$patients',
                  color: Colors.teal, onTap: () => onNavigate(1)),
              _StatCard(
                  icon: Icons.calendar_month, label: 'مواعيد اليوم', value: '$appts',
                  color: Colors.indigo, onTap: () => onNavigate(2)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _StatCard(
                  icon: Icons.check_circle, label: 'زيارات تمت اليوم', value: '${summary.visits}',
                  color: Colors.green, onTap: () => onNavigate(2)),
              _StatCard(
                  icon: Icons.payments, label: 'محصّل اليوم', value: summary.income.toStringAsFixed(0),
                  color: Colors.orange, onTap: () => onNavigate(3)),
            ]),
          ]);
        },
      ),
      const SizedBox(height: 20),
      const Text('إجراءات سريعة', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ActionChip(
            avatar: const Icon(Icons.person_add, size: 18),
            label: const Text('مريض جديد'),
            onPressed: () => onNavigate(1)),
        ActionChip(
            avatar: const Icon(Icons.event_available, size: 18),
            label: const Text('حجز موعد'),
            onPressed: () => onNavigate(2)),
        ActionChip(
            avatar: const Icon(Icons.receipt_long, size: 18),
            label: const Text('الخدمات والأسعار'),
            onPressed: () => onNavigate(3)),
        ActionChip(
            avatar: const Icon(Icons.settings, size: 18),
            label: const Text('النظام'),
            onPressed: () => onNavigate(4)),
      ]),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('نصائح تخصصك', style: TextStyle(fontWeight: FontWeight.bold)),
            ...spec.tips.take(3).map((t) => ListTile(
                dense: true,
                leading: const Icon(Icons.tips_and_updates, color: Colors.amber),
                title: Text(t))),
          ]),
        ),
      ),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  const _StatCard(
      {required this.icon, required this.label, required this.value,
       required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: color.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: color),
              const SizedBox(height: 12),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}
