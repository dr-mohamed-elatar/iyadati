import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../config/specialties.dart';
import '../../logic/validators.dart';
import '../../main.dart';
import '../../models/models.dart';
import '../../services/local_store.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});
  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  int _page = 1;
  String _query = '';
  Future<({List<Patient> rows, int total})>? _future;
  static const _size = 25;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = LocalStore.instance.patientsPage(page: _page, pageSize: _size, query: _query);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.push<bool>(
              context, MaterialPageRoute(builder: (_) => const PatientFormScreen()));
          if (saved == true) _load();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('مريض جديد'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'بحث بالاسم أو الهاتف',
                border: OutlineInputBorder()),
            onChanged: (v) {
              _query = v;
              _page = 1;
              _load();
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<({List<Patient> rows, int total})>(
            future: _future,
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final p = snap.data!;
              if (p.rows.isEmpty) return const Center(child: Text('لا يوجد مرضى بعد'));
              final pageCount = p.total == 0 ? 1 : ((p.total - 1) ~/ _size) + 1;
              return Column(children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: p.rows.length,
                    itemBuilder: (ctx, i) {
                      final pt = p.rows[i];
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(pt.name),
                        subtitle: Text('${pt.phone}${pt.age != null ? '  •  ${pt.age} سنة' : ''}'),
                        onTap: () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => PatientDetailsScreen(patientId: pt.id)));
                          _load();
                        },
                      );
                    },
                  ),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _page > 1
                          ? () {
                              _page--;
                              _load();
                            }
                          : null),
                  Text('$_page / $pageCount (الإجمالي ${p.total})'),
                  IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _page < pageCount
                          ? () {
                              _page++;
                              _load();
                            }
                          : null),
                ]),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

/// نموذج مريض: الحقول الأساسية + حقول التخصص المختار تلقائيًا
class PatientFormScreen extends StatefulWidget {
  const PatientFormScreen({super.key});
  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _nid = TextEditingController();
  final _age = TextEditingController();
  final _notes = TextEditingController();
  String _gender = 'ذكر';
  final Map<String, TextEditingController> _specControllers = {};
  final Map<String, String> _specSelects = {};

  @override
  Widget build(BuildContext context) {
    final spec = context.read<AppState>().specialty!;
    return Scaffold(
      appBar: AppBar(title: Text('مريض جديد — ${spec.name}')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'اسم المريض', border: OutlineInputBorder()),
              validator: (v) => validatePersonName(v ?? '', label: 'اسم المريض')),
          const SizedBox(height: 12),
          TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'الهاتف', border: OutlineInputBorder()),
              validator: (v) => validateEgyptianPhone(v ?? '')),
          const SizedBox(height: 12),
          TextFormField(
              controller: _nid,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'الرقم القومي (اختياري)', border: OutlineInputBorder()),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final r = validateEgyptianNationalId(v);
                return r.valid ? null : r.error;
              }),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextFormField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'السن', border: OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(normalizeDigits(v));
                    return (n == null || n < 0 || n > 120) ? 'سن غير صحيح' : null;
                  }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'النوع', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                  DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
                ],
                onChanged: (v) => setState(() => _gender = v ?? 'ذكر'),
              ),
            ),
          ]),
          const Divider(height: 32),
          Text('بيانات ${spec.name}:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final f in spec.fields) _buildSpecField(f),
          const SizedBox(height: 12),
          TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          FilledButton.icon(icon: const Icon(Icons.save), label: const Text('حفظ المريض'), onPressed: _save),
        ]),
      ),
    );
  }

  Widget _buildSpecField(SpecField f) {
    if (f.type == 'select') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          initialValue: _specSelects[f.key],
          decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder()),
          items: f.options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) => setState(() => _specSelects[f.key] = v ?? ''),
        ),
      );
    }
    final c = _specControllers.putIfAbsent(f.key, () => TextEditingController());
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: f.type == 'number' ? TextInputType.number
            : f.type == 'date' ? TextInputType.datetime
            : TextInputType.text,
        decoration: InputDecoration(
            labelText: f.label,
            hintText: f.type == 'date' ? 'yyyy-mm-dd' : null,
            border: const OutlineInputBorder()),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return null;
          if (f.type == 'number' && double.tryParse(normalizeDigits(v)) == null) {
            return '${f.label}: رقم غير صحيح';
          }
          if (f.type == 'date' && DateTime.tryParse(v.trim()) == null) {
            return '${f.label}: تاريخ غير صحيح (yyyy-mm-dd)';
          }
          return null;
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final specFields = <String, String>{};
    _specControllers.forEach((k, c) {
      if (c.text.trim().isNotEmpty) specFields[k] = c.text.trim();
    });
    _specSelects.forEach((k, v) {
      if (v.isNotEmpty) specFields[k] = v;
    });
    final pt = Patient(
      id: const Uuid().v4(),
      name: sanitizeName(_name.text),
      phone: normalizeDigits(_phone.text).replaceAll(RegExp(r'[^0-9]'), ''),
      nationalId: normalizeDigits(_nid.text).replaceAll(RegExp(r'[^0-9]'), ''),
      age: int.tryParse(normalizeDigits(_age.text)),
      gender: _gender,
      notes: _notes.text.trim(),
      specFields: specFields,
    );
    await LocalStore.instance.upsertPatient(pt);
    if (mounted) Navigator.pop(context, true);
  }
}

/// ملف المريض: بياناته + قياسات التخصص (بتحقق المدى) + زياراته
class PatientDetailsScreen extends StatelessWidget {
  final String patientId;
  const PatientDetailsScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    final spec = context.read<AppState>().specialty!;
    return Scaffold(
      appBar: AppBar(title: const Text('ملف المريض')),
      body: FutureBuilder<Patient?>(
        future: LocalStore.instance.patientById(patientId),
        builder: (ctx, snap) {
          final pt = snap.data;
          if (pt == null) return const Center(child: CircularProgressIndicator());
          return ListView(padding: const EdgeInsets.all(16), children: [
            ListTile(
              leading: const Icon(Icons.person, size: 40),
              title: Text(pt.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              subtitle: Text('${pt.phone}  •  ${pt.gender}${pt.age != null ? '  •  ${pt.age} سنة' : ''}'),
            ),
            if (pt.specFields.isNotEmpty) ...[
              const Divider(),
              Text('بيانات ${spec.name}:', style: const TextStyle(fontWeight: FontWeight.bold)),
              ...spec.fields.where((f) => (pt.specFields[f.key] ?? '').isNotEmpty).map(
                  (f) => ListTile(dense: true, title: Text(f.label), trailing: Text(pt.specFields[f.key]!))),
            ],
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('القياسات:', style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('قياس جديد'),
                onPressed: () => _addMeasurement(context, pt, spec),
              ),
            ]),
            FutureBuilder<List<MeasurementEntry>>(
              future: LocalStore.instance.measurementsOf(pt.id),
              builder: (ctx, ms) {
                final list = ms.data ?? [];
                if (list.isEmpty) return const Text('لا قياسات بعد', style: TextStyle(color: Colors.grey));
                return Column(children: [
                  for (final m in list)
                    ListTile(dense: true,
                        leading: const Icon(Icons.monitor_heart),
                        title: Text('${m.name}: ${m.value} ${m.unit}'),
                        subtitle: Text(m.date.toIso8601String().substring(0, 10))),
                ]);
              },
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _addMeasurement(BuildContext context, Patient pt, Specialty spec) async {
    Measurement? chosen = spec.measurements.first;
    final valueC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        return AlertDialog(
          title: const Text('قياس جديد'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<Measurement>(
              initialValue: chosen,
              decoration: const InputDecoration(labelText: 'القياس', border: OutlineInputBorder()),
              items: spec.measurements
                  .map((m) => DropdownMenuItem(value: m, child: Text('${m.name} (${m.unit})')))
                  .toList(),
              onChanged: (v) => setD(() => chosen = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valueC,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: chosen == null ? 'القيمة' : 'القيمة (من ${chosen!.min} إلى ${chosen!.max})',
                  border: const OutlineInputBorder()),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
          ],
        );
      }),
    );
    if (ok == true && chosen != null) {
      final err = validateMeasurement(chosen!.name, valueC.text, chosen!.min, chosen!.max);
      if (err != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(err)));
        }
        return;
      }
      await LocalStore.instance.addMeasurement(MeasurementEntry(
          id: const Uuid().v4(), patientId: pt.id, name: chosen!.name, unit: chosen!.unit,
          value: double.parse(normalizeDigits(valueC.text)), date: DateTime.now()));
      if (context.mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => PatientDetailsScreen(patientId: pt.id)));
      }
    }
  }
}
