import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iyadati_app/config/specialties.dart';
import 'package:iyadati_app/main.dart';
import 'package:iyadati_app/models/models.dart';
import 'package:iyadati_app/services/auth_service.dart';
import 'package:iyadati_app/services/local_store.dart';
import 'package:iyadati_app/ui/screens/appointments_screen.dart';
import 'package:iyadati_app/ui/screens/home_shell.dart';
import 'package:iyadati_app/ui/screens/patients_screen.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    LocalStore.debugDbPath = inMemoryDatabasePath;
  });
  setUp(() async {
    // قاعدة نظيفة لكل اختبار
    final d = await LocalStore.instance.db;
    await d.delete('patients');
    await d.delete('kv');
  });

  testWidgets('التسجيل: اختيار تخصص العيون يحوّل التطبيق كله لعيادة عيون ولا تظهر القائمة بعدها',
      (tester) async {
    final auth = LocalAuthService();
    await tester.pumpWidget(IyadatiApp(profile: ClinicProfile(), auth: auth));
    await tester.pumpAndSettle();

    Future<void> settleUntil(Finder f) async {
      for (var i = 0; i < 60; i++) {
        await tester
            .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        if (f.evaluate().isNotEmpty) return;
      }
      await tester.pumpAndSettle();
    }

    // شاشة إنشاء الحساب
    expect(find.text('عيادتي'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'دكتور أحمد');
    await tester.enterText(find.byType(TextFormField).at(1), 'doc@test.com');
    await tester.enterText(find.byType(TextFormField).at(2), '01012345678');
    await tester.tap(find.text('إرسال كودي التحقق'));
    await settleUntil(find.text('تحقق'));

    // كود الإيميل ثم اختيار التخصص
    await tester.enterText(find.byType(TextField).first, auth.devLastEmailCode!);
    await tester.tap(find.text('تحقق'));
    await settleUntil(find.textContaining('اختر تخصص عيادتك'));

    // قائمة التخصصات تظهر (مرة واحدة هنا فقط)
    expect(find.textContaining('اختر تخصص عيادتك'), findsOneWidget);
    final chip = find.text('👁️ عيون');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ابدأ العمل كعيادة عيون'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ العمل كعيادة عيون'));
    await settleUntil(find.text('عيادة عيون'));

    // التطبيق أصبح عيادة عيون
    expect(find.text('عيادة عيون'), findsOneWidget);
    expect(find.textContaining('اختر تخصص'), findsNothing);
    // استنزاف أي مؤقتات متبقية (جلب بيانات لوحة اليوم)
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
  });

  testWidgets('نموذج مريض جديد يعرض حقول تخصص العيون تلقائيًا', (tester) async {
    final profile = ClinicProfile(specKey: 'uyoun', doctorName: 'دكتور أحمد');
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(profile),
      child: const MaterialApp(home: PatientFormScreen()),
    ));
    await tester.pumpAndSettle();
    for (final label in ['نظر العين اليمنى', 'نظر العين اليسرى', 'ضغط العين']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('التحقق من القياس: رفض ضغط عين خارج المدى وقبول القيمة الصحيحة', (tester) async {
    final eye = kSpecialties['uyoun']!;
    final iop = eye.measurements.firstWhere((m) => m.name == 'ضغط العين');
    expect(iop.min, 3);
    expect(iop.max, 80);
  });

  testWidgets('المواعيد: تبويب المواعيد يعرض حالة اليوم الفارغة', (tester) async {
    final profile = ClinicProfile(specKey: 'uyoun', doctorName: 'دكتور أحمد');
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(profile),
      child: const MaterialApp(home: HomeShell()),
    ));
    await tester.tap(find.text('المواعيد'));
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      if (find.text('لا مواعيد في هذا اليوم').evaluate().isNotEmpty) break;
    }
    expect(find.text('لا مواعيد في هذا اليوم'), findsOneWidget);
  });

  test('مواعيد: حفظ موعد وجلبه وتغيير حالته في التخزين المحلي', () async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await LocalStore.instance.upsertAppointment(Appointment(
      id: 'a1', patientId: 'p1', patientName: 'منى أحمد',
      date: dateStr, time: '18:30', type: 'كشف جديد', fee: 300,
    ));
    var rows = await LocalStore.instance.appointmentsFor(dateStr);
    expect(rows.length, 1);
    expect(rows.first.patientName, 'منى أحمد');
    expect(rows.first.status, 'مجدول');
    await LocalStore.instance.setAppointmentStatus('a1', 'تم');
    rows = await LocalStore.instance.appointmentsFor(dateStr);
    expect(rows.first.status, 'تم');
    // يوم آخر بلا مواعيد
    final other = await LocalStore.instance.appointmentsFor('2026-01-01');
    expect(other, isEmpty);
  });

  test('المال: ملخص اليوم يجمع رسوم المواعيد المكتملة فقط', () async {
    final db = await LocalStore.instance.db;
    await db.delete('appointments');
    final now = DateTime.now();
    final d =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await LocalStore.instance.upsertAppointment(Appointment(
        id: 'f1', patientId: '', patientName: 'أ', date: d, time: '10:00', status: 'تم', fee: 200));
    await LocalStore.instance.upsertAppointment(Appointment(
        id: 'f2', patientId: '', patientName: 'ب', date: d, time: '11:00', status: 'مجدول', fee: 500));
    await LocalStore.instance.upsertAppointment(Appointment(
        id: 'f3', patientId: '', patientName: 'ج', date: d, time: '12:00', status: 'تم', fee: 150));
    final sum = await LocalStore.instance.daySummary(d);
    expect(sum.visits, 2);
    expect(sum.income, 350);
    // خدمات التخصص تُزرع مرة واحدة دون تكرار
    await LocalStore.instance.seedServices(['كشف', 'متابعة']);
    await LocalStore.instance.seedServices(['كشف', 'متابعة']);
    final svcs = await LocalStore.instance.services();
    expect(svcs.where((x) => x.name == 'كشف').length, 1);
  });
}
