

import 'local_store.dart';
import 'sync_service.dart';

/// نتيجة كل خطوة في التسجيل
class AuthResult {
  final bool ok;
  final String? error;
  const AuthResult.ok() : ok = true, error = null;
  const AuthResult.fail(this.error) : ok = false;
}

/// واجهة الدخول والتسجيل: بريد + كلمة سر (تأكيد البريد معطّل في Supabase —
/// لا إيميلات ولا حدود إرسال). استعادة كلمة السر برابط إيميل عند توفره.
abstract class AuthService {
  /// إنشاء حساب: بريد + كلمة سر، يدخل مباشرة بدون تأكيد.
  Future<AuthResult> register(
      {required String name,
      required String email,
      required String phone,
      required String password});

  /// دخول: بريد + كلمة سر لحساب موجود
  Future<AuthResult> login({required String email, required String password});

  /// إرسال رابط استعادة كلمة السر (يتطلب بريدًا مفعّلًا في Supabase)
  Future<AuthResult> resetPassword(String email);

  Future<AuthResult> verifyWhatsAppCode(String code);
  Future<bool> get hasAccount;
  Future<void> signOut();
}

String _friendlyAuthError(Object e) {
  final m = e.toString();
  if (m.contains('over_email_send_rate_limit') || m.contains('429')) {
    return 'تم إرسال عدد كبير من الرسائل — انتظر ساعة وحاول مجددًا';
  }
  if (m.contains('Invalid login credentials')) {
    return 'البريد أو كلمة السر غير صحيحة';
  }
  if (m.contains('User already registered')) {
    return 'هذا البريد مسجّل بالفعل — جرّب تسجيل الدخول';
  }
  if (m.contains('Password should be')) {
    return 'كلمة السر قصيرة — 6 أحرف على الأقل';
  }
  return 'تعذّر الاتصال بالخادم — تحقق من الإنترنت وحاول مجددًا';
}

/// تنفيذ سحابي: Supabase Auth ببريد + كلمة سر.
class SupabaseAuthService implements AuthService {
  Future<void> _ensureInit() async {
    await SyncService.instance.init();
  }

  @override
  Future<AuthResult> register(
      {required String name,
      required String email,
      required String phone,
      required String password}) async {
    await _ensureInit();
    try {
      await SyncService.instance.client.auth.signUp(
          email: email.trim(), password: password,
          data: {'name': name.trim(), 'phone': phone.trim()});
      await LocalStore.instance.setKv('pending_name', name.trim());
      await LocalStore.instance.setKv('pending_email', email.trim());
      await LocalStore.instance.setKv('pending_phone', phone.trim());
      await LocalStore.instance.setKv('account_verified', '1');
      return const AuthResult.ok();
    } catch (e) {
      return AuthResult.fail(_friendlyAuthError(e));
    }
  }

  @override
  Future<AuthResult> login({required String email, required String password}) async {
    await _ensureInit();
    try {
      await SyncService.instance.client.auth
          .signInWithPassword(email: email.trim(), password: password);
      await LocalStore.instance.setKv('account_verified', '1');
      // سحب ملف العيادة إن وُجد (جهاز جديد لنفس الحساب)
      await SyncService.instance.pullProfileIntoLocal();
      return const AuthResult.ok();
    } catch (e) {
      return AuthResult.fail(_friendlyAuthError(e));
    }
  }

  @override
  Future<AuthResult> resetPassword(String email) async {
    await _ensureInit();
    try {
      await SyncService.instance.client.auth.resetPasswordForEmail(email.trim(),
          redirectTo: 'https://dr-mohamed-elatar.github.io/iyadati/');
      return const AuthResult.ok();
    } catch (e) {
      return AuthResult.fail(_friendlyAuthError(e));
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

/// تنفيذ محلي كامل (وضع بلا سيرفر): يقبل أي كلمة سر ويخزن محليًا للاختبار.
class LocalAuthService implements AuthService {
  @override
  Future<AuthResult> register(
      {required String name,
      required String email,
      required String phone,
      required String password}) async {
    await LocalStore.instance.setKv('pending_name', name.trim());
    await LocalStore.instance.setKv('pending_email', email.trim());
    await LocalStore.instance.setKv('pending_phone', phone.trim());
    await LocalStore.instance.setKv('account_verified', '1');
    return const AuthResult.ok();
  }

  @override
  Future<AuthResult> login({required String email, required String password}) async {
    await LocalStore.instance.setKv('account_verified', '1');
    return const AuthResult.ok();
  }

  @override
  Future<AuthResult> resetPassword(String email) async => const AuthResult.ok();

  @override
  Future<AuthResult> verifyWhatsAppCode(String code) async {
    await LocalStore.instance.setKv('account_verified', '1');
    return const AuthResult.ok();
  }

  @override
  Future<bool> get hasAccount async =>
      (await LocalStore.instance.getKv('account_verified')) == '1';

  @override
  Future<void> signOut() async => LocalStore.instance.setKv('account_verified', '0');
}
