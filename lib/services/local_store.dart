import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/models.dart';

/// التخزين المحلي: يعمل دون إنترنت، والمزامنة السحابية (Supabase) تُبنى فوقه.
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();
  Database? _db;

  /// للاختبارات فقط: مسار مخصص (مثل inMemoryDatabasePath)
  static String? debugDbPath;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    DatabaseFactory factory;
    String path;
    if (debugDbPath != null) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
      path = debugDbPath!;
    } else if (kIsWeb) {
      factory = databaseFactoryFfiWeb;
      path = 'iyadati_web.db';
    } else if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      factory = databaseFactory;
      path = p.join((await getApplicationDocumentsDirectory()).path, 'iyadati.db');
    } else {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
      path = p.join((await getApplicationDocumentsDirectory()).path, 'iyadati.db');
    }
    return factory.openDatabase(path,
        options: OpenDatabaseOptions(version: 2, onUpgrade: (d, o, n) async { if (o < 2) { await d.execute('''CREATE TABLE IF NOT EXISTS appointments(id TEXT PRIMARY KEY, patient_id TEXT DEFAULT '', patient_name TEXT DEFAULT '', date TEXT NOT NULL, time TEXT DEFAULT '', type TEXT DEFAULT '', status TEXT DEFAULT 'مجدول', note TEXT DEFAULT '', fee REAL DEFAULT 0)'''); await d.execute('CREATE INDEX IF NOT EXISTS idx_appt_date ON appointments(date)'); } }, onCreate: (d, v) async {
          await d.execute('''CREATE TABLE patients(
            id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT DEFAULT '',
            national_id TEXT DEFAULT '', age INTEGER, gender TEXT DEFAULT '',
            blood TEXT DEFAULT '', allergies TEXT DEFAULT '', chronic TEXT DEFAULT '',
            notes TEXT DEFAULT '', spec_fields TEXT DEFAULT '{}', created_at TEXT)''');
          await d.execute('''CREATE TABLE measurements(
            id TEXT PRIMARY KEY, patient_id TEXT NOT NULL, name TEXT, unit TEXT DEFAULT '',
            value REAL, date TEXT)''');
          await d.execute('CREATE INDEX idx_meas_patient ON measurements(patient_id)');
          await d.execute('''CREATE TABLE visits(
            id TEXT PRIMARY KEY, patient_id TEXT NOT NULL, at TEXT, type TEXT DEFAULT '',
            dx TEXT DEFAULT '', rx TEXT DEFAULT '', note TEXT DEFAULT '', fee REAL DEFAULT 0)''');
          await d.execute('CREATE INDEX idx_visits_patient ON visits(patient_id)');
          await d.execute('''CREATE TABLE services(
            id TEXT PRIMARY KEY, name TEXT NOT NULL, price REAL DEFAULT 0)''');
          await d.execute('''CREATE TABLE kv(key TEXT PRIMARY KEY, value TEXT)''');
          await d.execute('''CREATE TABLE appointments(
            id TEXT PRIMARY KEY, patient_id TEXT DEFAULT '', patient_name TEXT DEFAULT '',
            date TEXT NOT NULL, time TEXT DEFAULT '', type TEXT DEFAULT '',
            status TEXT DEFAULT 'مجدول', note TEXT DEFAULT '', fee REAL DEFAULT 0)''');
          await d.execute('CREATE INDEX idx_appt_date ON appointments(date)');
        }));
  }

  Future<void> setKv(String key, String value) async {
    final d = await db;
    await d.insert('kv', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getKv(String key) async {
    final d = await db;
    final r = await d.query('kv', where: 'key = ?', whereArgs: [key], limit: 1);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  Future<ClinicProfile> profile() async {
    final v = await getKv('clinic_profile');
    if (v == null) return ClinicProfile();
    return ClinicProfile.fromMap(jsonDecode(v));
  }

  Future<void> saveProfile(ClinicProfile pr) => setKv('clinic_profile', jsonEncode(pr.toMap()));

  Future<({List<Patient> rows, int total})> patientsPage(
      {int page = 1, int pageSize = 25, String query = ''}) async {
    final d = await db;
    final where = query.trim().isEmpty ? '' : "WHERE name LIKE ? OR phone LIKE ?";
    final args = query.trim().isEmpty ? <Object?>[] : ['%${query.trim()}%', '%${query.trim()}%'];
    final total = (await d.rawQuery('SELECT COUNT(*) c FROM patients $where', args)).first['c'] as int;
    final rows = await d.rawQuery(
        'SELECT * FROM patients $where ORDER BY created_at DESC LIMIT ? OFFSET ?',
        [...args, pageSize, (page - 1) * pageSize]);
    return (rows: rows.map(Patient.fromMap).toList(), total: total);
  }

  Future<void> upsertPatient(Patient pt) async {
    final d = await db;
    await d.insert('patients', pt.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Patient?> patientById(String id) async {
    final d = await db;
    final r = await d.query('patients', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : Patient.fromMap(r.first);
  }

  Future<void> deletePatient(String id) async {
    final d = await db;
    final b = d.batch();
    b.delete('patients', where: 'id = ?', whereArgs: [id]);
    b.delete('measurements', where: 'patient_id = ?', whereArgs: [id]);
    b.delete('visits', where: 'patient_id = ?', whereArgs: [id]);
    await b.commit(noResult: true);
  }

  Future<List<MeasurementEntry>> measurementsOf(String patientId) async {
    final d = await db;
    final rows = await d.query('measurements',
        where: 'patient_id = ?', whereArgs: [patientId], orderBy: 'date DESC');
    return rows.map(MeasurementEntry.fromMap).toList();
  }

  Future<void> addMeasurement(MeasurementEntry m) async {
    final d = await db;
    await d.insert('measurements', m.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Visit>> visitsOf(String patientId) async {
    final d = await db;
    final rows = await d.query('visits',
        where: 'patient_id = ?', whereArgs: [patientId], orderBy: 'at DESC', limit: 50);
    return rows.map(Visit.fromMap).toList();
  }

  Future<List<Visit>> upcomingVisits() async {
    final d = await db;
    final now = DateTime.now().toIso8601String();
    final rows = await d.query('visits', where: 'at >= ?', whereArgs: [now], orderBy: 'at', limit: 100);
    return rows.map(Visit.fromMap).toList();
  }

  Future<void> addVisit(Visit v) async {
    final d = await db;
    await d.insert('visits', v.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ServiceItem>> services() async {
    final d = await db;
    final rows = await d.query('services', orderBy: 'name');
    return rows.map(ServiceItem.fromMap).toList();
  }

  Future<void> upsertService(ServiceItem s) async {
    final d = await db;
    await d.insert('services', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

  Future<List<Appointment>> appointmentsFor(String date) async {
    final d = await db;
    final rows = await d.query('appointments',
        where: 'date = ?', whereArgs: [date], orderBy: 'time ASC');
    return rows.map(Appointment.fromMap).toList();
  }

  Future<void> upsertAppointment(Appointment a) async {
    final d = await db;
    await d.insert('appointments', a.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setAppointmentStatus(String id, String status) async {
    final d = await db;
    await d.update('appointments', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAppointment(String id) async {
    final d = await db;
    await d.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }
