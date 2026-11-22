import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/specialties.dart';
import '../../logic/validators.dart';
import '../../main.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';

/// إنشاء حساب جديد: الاسم + الإيميل + الهاتف ← كود الإيميل ← كود الواتساب
/// ← اختيار التخصص (يظهر هنا فقط، ولا تظهر القائمة مرة أخرى داخل التطبيق).
class RegistrationScreen extends StatefulWidget {
  final AuthService auth;
  const RegistrationScreen({super.key, required this.auth});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  int _step = 0;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _emailCode = TextEditingController();
  final _waCode = TextEditingController();
  String? _error;
  String? _specKey;
  String _specQuery = '';

  Future<void> _start() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final r = await widget.auth.startRegistration(
        name: _name.text, email: _email.text, phone: _phone.text);
    debugPrint('RESULT ok=${r.ok} err=${r.error}');
    setState(() {
      if (r.ok) {
        _step = 1;
        _error = null;
      } else {
        _error = r.error;
      }
    });
  }

  Future<void> _verifyEmail() async {
    final r = await widget.auth.verifyEmailCode(_emailCode.text);
    setState(() {
      if (r.ok) {
        _step = 2;
        _error = null;
      } else {
        _error = r.error;
      }
    });
  }

  Future<void> _verifyWhatsApp() async {
    final r = await widget.auth.verifyWhatsAppCode(_waCode.text);
    setState(() {
      if (r.ok) {
        _step = 3;
        _error = null;
      } else {
        _error = r.error;
      }
    });
  }

  Future<void> _finish() async {
    if (_specKey == null) {
      setState(() => _error = 'اختر تخصصك من القائمة');
      return;
    }
    final app = context.read<AppState>();
    await app.saveProfile(ClinicProfile(
      specKey: _specKey!,
      doctorName: sanitizeName(_name.text),
      phone: _phone.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
            const Icon(Icons.local_hospital, size: 56, color: Color(0xFF0277BD)),
            const SizedBox(height: 8),
            const Text('عيادتي', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            Text(_stepTitle(), textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            if (_step == 0) _buildInfoStep(),
            if (_step == 1) _buildCodeStep(
                'كود الإيميل', 'أدخل الكود المكوّن من 6 أرقام الذي وصل بريدك', _emailCode, _verifyEmail),
            if (_step == 2) _buildCodeStep(
                'كود الواتساب', 'أدخل الكود الذي وصل واتساب على رقمك', _waCode, _verifyWhatsApp),
            if (_step == 3) _buildSpecialtyStep(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
              ),
          ]),
        ),
      ),
    );
  }

  String _stepTitle() => const [
        'إنشاء حساب جديد — بياناتك',
        'التحقق من البريد الإلكتروني',
        'التحقق من رقم الهاتف عبر واتساب',
        'اختر تخصص عيادتك (اختيار نهائي — لن تظهر هذه القائمة مرة أخرى)',
      ][_step];

  Widget _buildInfoStep() {
    return Form(
      key: _form,
      child: Column(children: [
        TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'اسم الطبيب', border: OutlineInputBorder()),
            validator: (v) => validatePersonName(v ?? '', label: 'اسم الطبيب')),
        const SizedBox(height: 12),
        TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder()),
            validator: (v) =>
                (v != null && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                    ? null
                    : 'بريد إلكتروني غير صالح'),
        const SizedBox(height: 12),
        TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'رقم الهاتف (واتساب)', hintText: '01xxxxxxxxx',
                border: OutlineInputBorder()),
            validator: (v) => validateEgyptianPhone(v ?? '')),
        const SizedBox(height: 16),
        FilledButton.icon(
            icon: const Icon(Icons.send), label: const Text('إرسال كودي التحقق'), onPressed: _start),
      ]),
    );
  }

  Widget _buildCodeStep(
      String label, String hint, TextEditingController c, Future<void> Function() onVerify) {
    return Column(children: [
      Text(hint, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      TextField(
          controller: c,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
      FilledButton.icon(icon: const Icon(Icons.verified), label: const Text('تحقق'), onPressed: onVerify),
    ]);
  }

  Widget _buildSpecialtyStep() {
    final q = _specQuery.trim();
    return Column(children: [
      TextField(
        decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'ابحث عن تخصصك',
            border: OutlineInputBorder()),
        onChanged: (v) => setState(() => _specQuery = v),
      ),
      const SizedBox(height: 8),
      ...kSpecialtyGroups.entries.map((g) {
        final keys = g.value.where((k) {
          final s = kSpecialties[k]!;
          return q.isEmpty || s.name.contains(q) || g.key.contains(q);
        }).toList();
        if (keys.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(g.key, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in keys)
              ChoiceChip(
                label: Text('${kSpecialties[k]!.emoji} ${kSpecialties[k]!.name}'),
                selected: _specKey == k,
                onSelected: (_) => setState(() => _specKey = k),
              ),
            // تخصصات الأسنان الفرعية تظهر مع مجموعة الأسنان
            if (g.key == 'أسنان')
              for (final k in const ['ortho', 'implant', 'pedo'])
                ChoiceChip(
                  label: Text('${kSpecialties[k]!.emoji} ${kSpecialties[k]!.name}'),
                  selected: _specKey == k,
                  onSelected: (_) => setState(() => _specKey = k),
                ),
          ]),
        ]);
      }),
      const SizedBox(height: 16),
      FilledButton.icon(
          icon: const Icon(Icons.check_circle),
          label: Text(_specKey == null
              ? 'ابدأ العمل'
              : 'ابدأ العمل كعيادة ${kSpecialties[_specKey]!.name}'),
          onPressed: _finish),
    ]);
  }
}
