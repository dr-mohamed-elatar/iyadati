import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/models.dart';
import 'local_store.dart';

/// المزامنة السحابية مع Supabase.
///
/// النموذج: دفعة رفع ثم تنزيل (رفع كل السجلات المحلية، ثم تنزيل كل سجلات
/// السيرفر ودمجها). مناسب لطبيب يعمل من جهاز واحد أساسي؛ التحديث الأخير يغلب
/// لأن السيرفر يحدّث updated_at عند كل تعديل، والتنزيل بعد الرفع يعيد نفس
/// الصفوف. الحذف يمرّ عبر شواهد (tombstones) محلية تُرفع كـ deleted=true.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  bool _ready = false;
  String? get userId => _ready ? Supabase.instance.client.auth.currentUser?.id : null;

  static const _tables = ['patients', 'measurements', 'visits', 'appointments', 'services'];

  Future<void> init() async {
    if (!SupabaseConfig.enabled || _ready) return;
    await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.publishableKey);
    LocalStore.onDelete = (table, id) => markDeleted(table, id);
    _ready = true;
  }

  bool get isActive => _ready && Supabase.instance.client.auth.currentUser != null;

  // ---------- شواهد الحذف المحلية ----------
  Future<List<String>> _tombstones(String table) async {
    final v = await LocalStore.instance.getKv('tomb_$table');
    return v == null ? [] : List<String>.from(jsonDecode(v));
  }

  Future<void> _clearTombstones(String table) => LocalStore.instance.setKv('tomb_$table', '[]');

  /// تُستدعى من LocalStore عند أي حذف محلي ليُرفع لاحقًا
  Future<void> markDeleted(String table, String id) async {
    final t = await _tombstones(table);
    if (!t.contains(id)) {
      t.add(id);
      await LocalStore.instance.setKv('tomb_$table', jsonEncode(t));
    }
  }

  // ---------- الرفع ----------
  Map<String, dynamic> _withUser(Map<String, dynamic> row) =>
      {...row, 'user_id': Supabase.instance.client.auth.currentUser!.id};

  Future<void> _pushTable(String table, Future<List<Map<String, dynamic>>> Function() rows) async {
    final client = Supabase.instance.client;
    final tombs = await _tombstones(table);
    for (final id in tombs) {
      await client.from(table).update({'deleted': true}).eq('id', id);
    }
    final data = (await rows()).map(_withUser).toList();
    if (data.isNotEmpty) {
      // دفعات لتفادي حدود الحجم
      for (var i = 0; i < data.length; i += 200) {
        await client.from(table).upsert(data.sublist(i, i + 200 > data.length ? data.length : i + 200));
      }
    }
    await _clearTombstones(table);
  }

  // ---------- التنزيل ----------
  Future<void> _pullTable(
      String table, Future<void> Function(Map<String, dynamic> row) apply) async {
    final client = Supabase.instance.client;
    final rows = await client.from(table).select().eq('deleted', false);
    for (final r in rows) {
      await apply(Map<String, dynamic>.from(r));
    }
  }

  /// مزامنة كاملة: رفع كل المحلي ثم تنزيل كل السيرفر.
  /// تُستدعى عند بدء التطبيق وبعد كل تعديل محلي (خفيفة على بيانات عيادة واحدة).
  Future<bool> syncNow() async {
    if (!isActive) return false;
    try {
      // رفع
      await _pushTable('patients', () async {
        final all = <Map<String, dynamic>>[];
        var page = 1;
        while (true) {
          final r = await LocalStore.instance.patientsPage(page: page, pageSize: 200);
          all.addAll(r.rows.map((p) => p.toMap()
            ..['spec_fields'] = jsonDecode(p.toMap()['spec_fields'] as String)));
          if (all.length >= r.total) break;
          page++;
        }
        return all;
      });
      await _pushTable('measurements', () async {
        final d = await LocalStore.instance.db;
        return d.query('measurements');
      });
      await _pushTable('visits', () async {
        final d = await LocalStore.instance.db;
        return d.query('visits');
      });
      await _pushTable('appointments', () async {
        final d = await LocalStore.instance.db;
        return d.query('appointments');
      });
      await _pushTable('services', () async {
        final d = await LocalStore.instance.db;
        return d.query('services');
      });
      // ملف العيادة
      final profile = await LocalStore.instance.profile();
      if (profile.hasSpecialty) {
        await Supabase.instance.client.from('clinic_profiles').upsert({
          'user_id': Supabase.instance.client.auth.currentUser!.id,
          'spec_key': profile.specKey,
          'clinic_name': profile.clinicName,
          'doctor_name': profile.doctorName,
          'address': profile.address,
          'phone': profile.phone,
          'fee': profile.fee,
          'open': profile.open,
        });
      }

      // تنزيل
      await _pullTable('patients', (r) async {
        r['spec_fields'] = jsonEncode(r['spec_fields'] ?? {});
        await LocalStore.instance.upsertPatient(Patient.fromMap(r));
      });
      await _pullTable('measurements', (r) async {
        await LocalStore.instance.addMeasurement(MeasurementEntry.fromMap(r));
      });
      await _pullTable('visits', (r) async {
        await LocalStore.instance.addVisit(Visit.fromMap(r));
      });
      await _pullTable('appointments', (r) async {
        await LocalStore.instance.upsertAppointment(Appointment.fromMap(r));
      });
      await _pullTable('services', (r) async {
        await LocalStore.instance.upsertService(ServiceItem.fromMap(r));
      });
      return true;
    } catch (e) {
      debugPrint('sync failed: $e');
      return false;
    }
  }
}
