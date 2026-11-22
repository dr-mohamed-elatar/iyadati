import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;

import 'local_store.dart';
import 'sync_service.dart';

/// نتيجة كل خطوة في التسجيل
class AuthResult {
  final bool ok;
  final String? error;
  const AuthResult.ok() : ok = true, error = null;
  const AuthResult.fail(this.error) : ok = false;
}

/// واجهة الدخول والتسجيل بكود يصل على الإيميل (بدون كلمة سر — الكود هو
/// طريق الدخول واستعادتها). التنفيذ السحابي Supabase، والمحلي للاختبار.
abstract class AuthService {
  /// إنشاء حساب: يرسل كود الإيميل. (واتساب يُجمع رقمه ويُوثَّق لاحقًا)
  Future<AuthResult> startRegistration(
      {required String name, required String email, required String phone});

  /// دخول: يرسل كود الإيميل لحساب موجود
  Future<AuthResult> startLogin(String email);

  Future<AuthResult> verifyEmailCode(String code);
  Future<AuthResult> verifyWhatsAppCode(String code);
  Future<bool> get hasAccount;
  Future<void> signOut();
}

/// تنفيذ سحابي: Supabase Auth بكود إيميل (OTP).
class SupabaseAuthService implements AuthService {
  String? _pendingEmail;

  Future<void> _ensureInit() async {
    await SyncService.instance.init();
  }

  @override
  Future<AuthResult> startRegistration(
      {required String name, required String email, required String phone}) async {
    await _ensureInit();
    _pendingEmail = email.trim();
    await LocalStore.instance.setKv('pending_name', name.trim());
    await LocalStore.instance.setKv('pending_email', _pendingEmail!);
    await LocalStore.instance.setKv('pending_phone', phone.trim());
    return _sendOtp(_pendingEmail!);
  }

  @override
  Future<AuthResult> startLogin(String email) async {
    await _ensureInit();
    _pendingEmail = email.trim();
    return _sendOtp(_pendingEmail!);
  }

  Future<AuthResult> _sendOtp(String email) async {
    try {
      await SyncService.instance.client.auth.signInWithOtp(email: email);
      return const AuthResult.ok();
    } catch (e) {
      return AuthResult.fail('تعذر إرسال الكود: $e');
    }
  }

  @override
  Future<AuthResult> verifyEmailCode(String code) async {
    await _ensureInit();
    final email = _pendingEmail ?? await LocalStore.instance.getKv('pending_email');
    if (email == null) return const AuthResult.fail('اطلب الكود أولًا');
    try {
      // ignore: deprecated_member_use
      await SyncService.instance.client.auth
          .verifyOTP(type: OtpType.email, token: code.trim(), email: email);
      await LocalStore.instance.setKv('account_verified', '1');
      // سحب ملف العيادة إن وُجد (جهاز جديد لنفس الحساب)
      await SyncService.instance.pullProfileIntoLocal();
      return const AuthResult.ok();
    } catch (e) {
      return AuthResult.fail('الكود غير صحيح أو منتهي');
    }
  }

  /// توثيق واتساب يتطلب ربط واتساب للأعمال (مدفوع لكل رسالة) — مؤجل.
  @override
  Future<AuthResult> verifyWhatsAppCode(String code) async => const AuthResult.ok();

  @override
  Future<bool> get hasAccount async {
    await _ensureInit();
    if (SyncService.instance.isActive) return true;
    return (await LocalStore.instance.getKv('account_verified')) == '1';
  }

  @override
  Future<void> signOut() async {
    await _ensureInit();
    await SyncService.instance.client.auth.signOut();
    await LocalStore.instance.setKv('account_verified', '0');
  }
}

/// تنفيذ محلي كامل (وضع بلا سيرفر): يولّد الأكواد ويخزنها محليًا للاختبار.
class LocalAuthService implements AuthService {
  String? _pendingEmailCode;
  String? _pendingWhatsAppCode;
  String? _pendingEmail;
  String? _pendingPhone;

  /// للاختبار فقط: الكود المولّد آخر مرة (لا يُعرض للمستخدم النهائي)
  String? get devLastEmailCode => _pendingEmailCode;
  String? get devLastWhatsAppCode => _pendingWhatsAppCode;

  String _code() => (100000 + (DateTime.now().microsecondsSinceEpoch % 900000)).toString();

  @override
  Future<AuthResult> startRegistration(
      {required String name, required String email, required String phone}) async {
    _pendingEmailCode = _code();
    _pendingWhatsAppCode = _code();
    _pendingEmail = email.trim();
    _pendingPhone = phone.trim();
    await LocalStore.instance.setKv('pending_name', name.trim());
    await LocalStore.instance.setKv('pending_email', _pendingEmail!);
    await LocalStore.instance.setKv('pending_phone', _pendingPhone!);
    return const AuthResult.ok();
  }

  @override
  Future<AuthResult> startLogin(String email) async {
    _pendingEmailCode = _code();
    _pendingEmail = email.trim();
    return const AuthResult.ok();
  }

  @override
  Future<AuthResult> verifyEmailCode(String code) async {
    if (_pendingEmailCode != null && code.trim() == _pendingEmailCode) {
      return const AuthResult.ok();
    }
    return const AuthResult.fail('كود الإيميل غير صحيح');
  }

  @override
  Future<AuthResult> verifyWhatsAppCode(String code) async {
    if (_pendingWhatsAppCode != null && code.trim() == _pendingWhatsAppCode) {
      await LocalStore.instance.setKv('account_verified', '1');
      return const AuthResult.ok();
    }
    return const AuthResult.fail('كود الواتساب غير صحيح');
  }

  @override
  Future<bool> get hasAccount async =>
      (await LocalStore.instance.getKv('account_verified')) == '1';

  @override
  Future<void> signOut() async => LocalStore.instance.setKv('account_verified', '0');
}
