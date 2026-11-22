import 'local_store.dart';

/// نتيجة كل خطوة في التسجيل
class AuthResult {
  final bool ok;
  final String? error;
  const AuthResult.ok() : ok = true, error = null;
  const AuthResult.fail(this.error) : ok = false;
}

/// واجهة التسجيل: تحقق بالهاتف (واتساب OTP افتراضيًا) + كود OTP على الإيميل.
/// التنفيذ السحابي (Supabase + Meta WhatsApp Cloud API) يُفعَّل بعد وصول
/// بيانات الاعتماد؛ حتى ذلك الحين يعمل التنفيذ المحلي الكامل للاختبار.
abstract class AuthService {
  /// يبدأ التسجيل: يرسل كود الإيميل ثم كود الواتساب
  Future<AuthResult> startRegistration(
      {required String name, required String email, required String phone});
  Future<AuthResult> verifyEmailCode(String code);
  Future<AuthResult> verifyWhatsAppCode(String code);
  Future<bool> get hasAccount;
}

/// تنفيذ محلي كامل (وضع بلا سيرفر): يولّد الأكواد ويخزنها محليًا للاختبار.
/// في النسخة النهائية تُرسل الأكواد فعليًا؛ هنا تُعرض في وضع المطور فقط.
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
}
