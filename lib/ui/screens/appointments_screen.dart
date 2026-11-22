import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../main.dart';
import '../../models/models.dart';
import '../../services/local_store.dart';

/// جدول مواعيد اليوم: إضافة/إتمام/إلغاء، وأنواع الزيارة من تخصص العيادة
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});
  @override
  State<AppointmentsScreen> createState() => AppointmentsScreenState();
}

class AppointmentsScreenState extends State<AppointmentsScreen> {
  DateTime _day = DateTime.now();
  List<Appointment> _items = [];
  bool _loading = true;

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final rows = await LocalStore.instance.appointmentsFor(_fmt(_day));
    if (mounted) setState(() { _items = rows; _loading = false; });
  }

  Future<void> addDialog() async {
    final spec = context.read<AppState>().specialty!;
    final pts = (await LocalStore.instance.patientsPage(pageSize: 200)).rows;
    if (!mounted) return;
    Patient? chosen = pts.isNotEmpty ? pts.first : null;
    final nameCtrl = TextEditingController(text: chosen?.name ?? '');
    final feeCtrl = TextEditingController(
        text: context.read<AppState>().profile.fee > 0
            ? context.read<AppState>().profile.fee.toStringAsFixed(0)
            : '');
    String type = spec.visits.isNotEmpty ? spec.visits.first : 'كشف';
    TimeOfDay tod = TimeOfDay.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        title: const Text('موعد جديد'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (pts.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: chosen?.id,
              decoration: const InputDecoration(labelText: 'المريض'),
              items: [
                for (final p in pts)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => ss(() {
                chosen = pts.firstWhere((p) => p.id == v);
                nameCtrl.text = chosen!.name;
              }),
            )
          else
            TextFormField(controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم المريض')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'نوع الزيارة'),
            items: [for (final t in spec.visits) DropdownMenuItem(value: t, child: Text(t))],
            onChanged: (v) => ss(() => type = v ?? type),
          ),
          const SizedBox(height: 8),
          TextFormField(controller: feeCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'السعر (جنيه)')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.access_time),
            label: Text('الساعة ${tod.format(ctx)}'),
            onPressed: () async {
              final t = await showTimePicker(context: ctx, initialTime: tod);
              if (t != null) ss(() => tod = t);
            },
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      )),
    );
    if (ok != true) return;
    final timeStr = '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';
    final a = Appointment(
      id: const Uuid().v4(),
      patientId: chosen?.id ?? '',
      patientName: chosen?.name ?? nameCtrl.text.trim(),
      date: _fmt(_day),
      time: timeStr,
      type: type,
      fee: double.tryParse(feeCtrl.text.trim()) ?? 0,
    );
    await LocalStore.instance.upsertAppointment(a);
    await reload();
  }

  Future<void> _setStatus(Appointment a, String status) async {
    await LocalStore.instance.setAppointmentStatus(a.id, status);
    await reload();
  }

  Color _statusColor(String s) => switch (s) {
        'تم' => Colors.green,
        'ملغي' => Colors.red,
        'لم يحضر' => Colors.orange,
        _ => Colors.blue,
      };

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.chevron_right),
              onPressed: () { setState(() { _day = _day.subtract(const Duration(days: 1)); _loading = true; }); reload(); }),
          Text(_fmt(_day), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.chevron_left),
              onPressed: () { setState(() { _day = _day.add(const Duration(days: 1)); _loading = true; }); reload(); }),
          TextButton(
              onPressed: () { setState(() { _day = DateTime.now(); _loading = true; }); reload(); },
              child: const Text('اليوم')),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(child: Text('لا مواعيد في هذا اليوم'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final a = _items[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(child: Text(a.time, style: const TextStyle(fontSize: 11))),
                          title: Text(a.patientName.isEmpty ? 'بدون اسم' : a.patientName),
                          subtitle: Text('${a.type}${a.fee > 0 ? ' • ${a.fee.toStringAsFixed(0)} جنيه' : ''}'),
                          trailing: PopupMenuButton<String>(
                            initialValue: a.status,
                            onSelected: (v) => _setStatus(a, v),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'مجدول', child: Text('مجدول')),
                              PopupMenuItem(value: 'تم', child: Text('تم')),
                              PopupMenuItem(value: 'لم يحضر', child: Text('لم يحضر')),
                              PopupMenuItem(value: 'ملغي', child: Text('ملغي')),
                            ],
                            child: Chip(
                              label: Text(a.status, style: const TextStyle(color: Colors.white, fontSize: 12)),
                              backgroundColor: _statusColor(a.status),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }
}

/// زر الإضافة يعيش في HomeShell عبر مفتاح عام
class AppointmentsFab extends StatelessWidget {
  final GlobalKey<AppointmentsScreenState> stateKey;
  const AppointmentsFab({super.key, required this.stateKey});
  @override
  Widget build(BuildContext context) => FloatingActionButton(
        onPressed: () => stateKey.currentState?.addDialog(),
        child: const Icon(Icons.add),
      );
}
