import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'local_store.dart';

/// التفعيل والترخيص — نفس نموذج تطبيق داري: سر المطور يضعه المالك داخل
/// التطبيق (لا يوجد أي سر في الكود)، وكود التفعيل مرتبط ببصمة الجهاز:
/// HMAC-SHA256(سر المطور, بصمة الجهاز | تاريخ الانتهاء | حد المرضى)
/// يمكن لاحقًا استبدال التحقق المحلي بخادم الترخيص (Supabase) دون تغيير الواجهة.
class LicenseInfo {
  final String code;
  final DateTime expiresAt;
  final int maxPatients; // 0 = بلا حد
  final String deviceFp;
  const LicenseInfo({
    required this.code,
    required this.expiresAt,
    this.maxPatients = 0,
    required this.deviceFp,
  });

  bool get active => expiresAt.isAfter(DateTime.now());
  int get daysLeft => expiresAt.difference(DateTime.now()).inDays;

  Map<String, dynamic> toJson() => {
        'code': code,
        'expires_at': expiresAt.toIso8601String(),
        'max_patients': maxPatients,
        'device_fp': deviceFp,
      };
  factory LicenseInfo.fromJson(Map<String, dynamic> m) => LicenseInfo(
        code: m['code'] ?? '',
        expiresAt: DateTime.tryParse(m['expires_at'] ?? '') ?? DateTime(2000),
        maxPatients: (m['max_patients'] as num?)?.toInt() ?? 0,
        deviceFp: m['device_fp'] ?? '',
      );
}

class LicenseService {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  static const _currentKey = 'lic_current';
  static const _secretKey = 'lic_dev_secret';
  static const _logKey = 'lic_activation_log';

  Future<String> deviceFingerprint() async {
    final info = DeviceInfoPlugin();
    String raw;
    if (kIsWeb) {
      final w = await info.webBrowserInfo;
      raw = 'web:${w.userAgent}';
    } else {
      final a = await info.androidInfo;
      raw = 'android:${a.id}';
    }
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 16).toUpperCase();
  }

  Future<String?> devSecret() => LocalStore.instance.getKv(_secretKey);

  Future<void> setDevSecret(String secret) => LocalStore.instance.setKv(_secretKey, secret);

  /// توليد كود تفعيل لجهاز ببصمة معينة (يُستخدم في قسم المطور فقط)
  String generateCode({
    required String secret,
    required String deviceFp,
    required DateTime expiresAt,
    int maxPatients = 0,
  }) {
    final payload = '$deviceFp|${expiresAt.toIso8601String().substring(0, 10)}|$maxPatients';
    final h = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(payload)).toString();
    final groups = <String>[];
    for (var i = 0; i < 5; i++) {
      groups.add(h.substring(i * 5, i * 5 + 5).toUpperCase());
    }
    return groups.join('-');
  }

  /// تفعيل النسخة بكود — يتحقق محليًا بسر المطور وبصمة الجهاز
  Future<LicenseInfo?> activate(String code, {DateTime? expiresAt, int maxPatients = 0}) async {
    final secret = await devSecret();
    if (secret == null) return null;
    final fp = await deviceFingerprint();
    final exp = expiresAt ?? DateTime.now().add(const Duration(days: 365));
    final expected =
        generateCode(secret: secret, deviceFp: fp, expiresAt: exp, maxPatients: maxPatients);
    if (expected != code.trim().toUpperCase()) return null;
    final info = LicenseInfo(code: expected, expiresAt: exp, maxPatients: maxPatients, deviceFp: fp);
    await LocalStore.instance.setKv(_currentKey, jsonEncode(info.toJson()));
    await _log('تفعيل ناجح حتى ${exp.toIso8601String().substring(0, 10)}');
    return info;
  }

  Future<LicenseInfo?> current() async {
    final v = await LocalStore.instance.getKv(_currentKey);
    if (v == null) return null;
    try {
      final info = LicenseInfo.fromJson(jsonDecode(v));
      // الترخيص مرتبط بالجهاز: بصمة مختلفة = نسخة منقولة
      final fp = await deviceFingerprint();
      if (info.deviceFp != fp) return null;
      return info.active ? info : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> activationLog() async {
    final v = await LocalStore.instance.getKv(_logKey);
    if (v == null) return [];
    return List<String>.from(jsonDecode(v));
  }

  Future<void> _log(String entry) async {
    final log = await activationLog();
    log.add('${DateTime.now().toIso8601String()} — $entry');
    await LocalStore.instance.setKv(_logKey, jsonEncode(log));
  }

  /// 0 = بلا حد
  String? checkLimit(LicenseInfo? info, {required int currentPatients}) {
    if (info == null) return 'النسخة غير مفعّلة';
    if (info.maxPatients > 0 && currentPatients >= info.maxPatients) {
      return 'بلوغ حد الباقة (${info.maxPatients})';
    }
    return null;
  }
}
