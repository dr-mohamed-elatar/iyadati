import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../services/license_service.dart';

/// شاشة النظام: بيانات العيادة + قسم المطور (الترخيص) محمي بسر المطور.
class SettingsScreen extends StatefulWidget {
  final List<String> tips;
  const SettingsScreen({super.key, this.tips = const []});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final spec = app.specialty;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('العيادة', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ListTile(
        leading: const Icon(Icons.local_hospital),
        title: Text(app.profile.clinicName.isEmpty ? 'بدون اسم' : app.profile.clinicName),
        subtitle: Text(spec == null ? '' : 'تخصص: ${spec.name}'),
      ),
      ListTile(
        leading: const Icon(Icons.person),
        title: Text(app.profile.doctorName.isEmpty ? '—' : app.profile.doctorName),
        subtitle: Text(app.profile.phone),
      ),
      const Divider(height: 32),
      if (widget.tips.isNotEmpty) ...[
        const Text('نصائح تخصصك:', style: TextStyle(fontWeight: FontWeight.bold)),
        ...widget.tips.map((t) =>
            ListTile(leading: const Icon(Icons.tips_and_updates, color: Colors.amber), title: Text(t))),
        const Divider(height: 32),
      ],
      const _DeveloperSection(),
    ]);
  }
}

/// قسم المطور: ضبط سر المطور (مرة)، توليد أكواد التفعيل لأجهزة العملاء،
/// وعرض الترخيص الحالي وسجل التفعيلات. يُفتح بسر المطور نفسه.
class _DeveloperSection extends StatefulWidget {
  const _DeveloperSection();

  @override
  State<_DeveloperSection> createState() => _DeveloperSectionState();
}

class _DeveloperSectionState extends State<_DeveloperSection> {
  bool _unlocked = false;
  bool _hasSecret = false;
  LicenseInfo? _license;
  List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final lic = LicenseService.instance;
    final s = await lic.devSecret();
    final cur = await lic.current();
    final log = await lic.activationLog();
    if (!mounted) return;
    setState(() {
      _hasSecret = s != null;
      _license = cur;
      _log = log.reversed.toList();
    });
  }

  Future<void> _unlock() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_hasSecret ? 'سر المطور' : 'تعيين سر المطور (لتوليد الأكواد)'),
        content: TextField(
          controller: c,
          obscureText: true,
          decoration: InputDecoration(
              labelText: _hasSecret ? 'أدخل سر المطور' : 'اختر سرًّا قويًّا واحفظه لديك'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    final lic = LicenseService.instance;
    final existing = await lic.devSecret();
    if (existing == null) {
      await lic.setDevSecret(c.text.trim());
      setState(() => _unlocked = true);
    } else if (existing == c.text.trim()) {
      setState(() => _unlocked = true);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('سر المطور غير صحيح')));
      }
      return;
    }
    _refresh();
  }

  Future<void> _generate() async {
    final fp = TextEditingController();
    final days = TextEditingController(text: '365');
    final maxP = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('توليد كود تفعيل'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: fp,
              decoration: const InputDecoration(labelText: 'بصمة جهاز العميل')),
          TextField(
              controller: days,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المدة بالأيام')),
          TextField(
              controller: maxP,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'حد المرضى (0 = بلا حد)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('توليد')),
        ],
      ),
    );
    if (ok != true || fp.text.trim().isEmpty) return;
    final secret = await LicenseService.instance.devSecret();
    if (secret == null) return;
    final code = LicenseService.instance.generateCode(
      secret: secret,
      deviceFp: fp.text.trim().toUpperCase(),
      expiresAt: DateTime.now().add(Duration(days: int.tryParse(days.text) ?? 365)),
      maxPatients: int.tryParse(maxP.text) ?? 0,
    );
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('كود التفعيل'),
        content: SelectableText(code, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
            },
            child: const Text('نسخ'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('تم')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('قسم المطور', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (!_unlocked)
        OutlinedButton.icon(
          onPressed: _unlock,
          icon: Icon(_hasSecret ? Icons.vpn_key : Icons.key_off),
          label: Text(_hasSecret ? 'فتح قسم المطور' : 'تعيين سر المطور'),
        )
      else ...[
        ListTile(
          leading: Icon(_license != null ? Icons.verified : Icons.error_outline,
              color: _license != null ? Colors.green : Colors.red),
          title: Text(_license != null
              ? 'نسخة مفعّلة حتى ${_license!.expiresAt.toIso8601String().substring(0, 10)}'
              : 'النسخة غير مفعّلة'),
          subtitle: _license != null && _license!.maxPatients > 0
              ? Text('حد المرضى: ${_license!.maxPatients}')
              : null,
        ),
        FilledButton.icon(
          onPressed: _generate,
          icon: const Icon(Icons.qr_code),
          label: const Text('توليد كود تفعيل لعميل'),
        ),
        if (_log.isNotEmpty) ...[
          const Divider(height: 32),
          const Text('سجل التفعيلات:', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._log.take(10).map((e) => Text(e, style: const TextStyle(fontSize: 12))),
        ],
      ],
    ]);
  }
}
