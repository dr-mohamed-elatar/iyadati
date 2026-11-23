import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/specialties.dart';
import '../../logic/validators.dart';
import '../../main.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';

/// دخول أو إنشاء حساب: بريد + كلمة سر (بدون تأكيد بريد — دخول مباشر).
/// بعد إنشاء الحساب: اختيار التخصص (يظهر هنا فقط).
/// توثيق واتساب يتطلب ربط واتساب للأعمال (مدفوع) — يُجمع الرقم ويُوثَّق لاحقًا.
class RegistrationScreen extends StatefulWidget {
  final AuthService auth;
  const RegistrationScreen({super.key, required this.auth});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  int _step = 0;
  bool _isLogin = false;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  String? _specKey;
  String _specQuery = '';

  Future<void> _start() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final r = _isLogin
        ? await widget.auth.login(email: _email.text, password: _password.text)
        : await widget.auth.register(
            name: _name.text,
            email: _email.text,
            phone: _phone.text,
            password: _password.text);
    if (!r.ok) {
      setState(() => _error = r.error);
      return;
    }
    if (_isLogin) {
      // سحب ملف العيادة من السحابة (تم داخل login) ثم التحديث
      if (!mounted) return;
      final app = context.read<AppState>();
      await app.reloadProfile();
      if (app.profile.hasSpecialty) return; // يدخل التطبيق مباشرة
    }
    setState(() {
      _step = 2;
      _error = null;
    });
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'أدخل بريدك أولًا ثم اضغط نسيت كلمة السر');
      return;
    }
    final r = await widget.auth.resetPassword(email);
    setState(() => _error =
        r.ok ? 'أرسلنا رابط إعادة التعيين إلى بريدك إن كان مسجّلًا' : r.error);
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
            if (_step == 2) _buildSpecialtyStep(),
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

  String _stepTitle() => _step == 0
      ? (_isLogin ? 'تسجيل الدخول بالبريد الإلكتروني وكلمة السر' : 'إنشاء حساب جديد: بياناتك')
      : const [
          '',
          'التحقق من البريد الإلكتروني',
          'اختر تخصص عيادتك (اختيار نهائي: لن تظهر هذه القائمة مرة أخرى)',
        ][_step];

  Widget _buildInfoStep() {
    return Form(
      key: _form,
      child: Column(children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('حساب جديد')),
            ButtonSegment(value: true, label: Text('تسجيل الدخول')),
          ],
          selected: {_isLogin},
          onSelectionChanged: (v) => setState(() => _isLogin = v.first),
        ),
        const SizedBox(height: 16),
        if (!_isLogin) ...[
          TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'اسم الطبيب', border: OutlineInputBorder()),
              validator: (v) => validatePersonName(v ?? '', label: 'اسم الطبيب')),
          const SizedBox(height: 12),
        ],
        TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder()),
            validator: (v) =>
                (v != null && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                    ? null
                    : 'بريد إلكتروني غير صالح'),
        const SizedBox(height: 12),
        if (!_isLogin)
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'رقم الهاتف (واتساب)', hintText: '01xxxxxxxxx',
                border: OutlineInputBorder()),
            validator: (v) => _isLogin ? null : validateEgyptianPhone(v ?? '')),
        if (!_isLogin)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('توثيق واتساب غير مفعّل حاليًا',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        const SizedBox(height: 12),
        TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'كلمة السر', border: OutlineInputBorder()),
            validator: (v) =>
                (v != null && v.length >= 6) ? null : 'كلمة السر: 6 أحرف على الأقل'),
        if (_isLogin)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
                onPressed: _forgotPassword,
                child: const Text('نسيت كلمة السر؟')),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
            icon: Icon(_isLogin ? Icons.login : Icons.person_add),
            label: Text(_isLogin ? 'تسجيل الدخول' : 'إنشاء الحساب'),
            onPressed: _start),
      ]),
    );
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
