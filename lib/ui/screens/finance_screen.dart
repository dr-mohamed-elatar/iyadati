import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../main.dart';
import '../../models/models.dart';
import '../../services/local_store.dart';

/// المال والخدمات: ملخص اليوم + قائمة خدمات التخصص بأسعار قابلة للتعديل
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override
  State<FinanceScreen> createState() => FinanceScreenState();
}

class FinanceScreenState extends State<FinanceScreen> {
  List<ServiceItem> _services = [];
  int _visits = 0;
  double _income = 0;
  bool _loading = true;

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final spec = context.read<AppState>().specialty!;
    await LocalStore.instance.seedServices(spec.services);
    final svcs = await LocalStore.instance.services();
    final sum = await LocalStore.instance.daySummary(_fmt(DateTime.now()));
    if (mounted) {
      setState(() {
        _services = svcs;
        _visits = sum.visits;
        _income = sum.income;
        _loading = false;
      });
    }
  }

  Future<void> _editPrice(ServiceItem svc) async {
    final ctrl = TextEditingController(text: svc.price.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('سعر: ${svc.name}'),
        content: TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'السعر (جنيه)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) return;
    svc.price = double.tryParse(ctrl.text.trim()) ?? svc.price;
    await LocalStore.instance.upsertService(svc);
    await reload();
  }

  Future<void> _addService() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('خدمة جديدة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الخدمة')),
          TextFormField(controller: priceCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'السعر (جنيه)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    await LocalStore.instance.upsertService(ServiceItem(
      id: const Uuid().v4(),
      name: nameCtrl.text.trim(),
      price: double.tryParse(priceCtrl.text.trim()) ?? 0,
    ));
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      body: ListView(padding: const EdgeInsets.all(12).copyWith(bottom: 80), children: [
        Row(children: [
          Expanded(child: _StatCard(title: 'زيارات اليوم', value: '$_visits', icon: Icons.check_circle)),
          const SizedBox(width: 8),
          Expanded(child: _StatCard(
              title: 'محصّل اليوم', value: '${_income.toStringAsFixed(0)} جنيه', icon: Icons.payments)),
        ]),
        const SizedBox(height: 16),
        const Text('الخدمات والأسعار', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final svc in _services)
          Card(
            child: ListTile(
              title: Text(svc.name),
              trailing: Text(svc.price > 0 ? '${svc.price.toStringAsFixed(0)} جنيه' : 'بدون سعر',
                  style: TextStyle(
                      color: svc.price > 0 ? Colors.green.shade700 : Colors.grey,
                      fontWeight: FontWeight.bold)),
              onTap: () => _editPrice(svc),
            ),
          ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _addService,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  const _StatCard({required this.title, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Icon(icon, size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ]),
        ),
      );
}
