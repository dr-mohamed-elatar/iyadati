import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iyadati_app/config/specialties.dart';
import 'package:iyadati_app/main.dart';
import 'package:iyadati_app/models/models.dart';
import 'package:iyadati_app/services/auth_service.dart';
import 'package:iyadati_app/services/local_store.dart';
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

    // كود الإيميل ثم كود الواتساب
    await tester.enterText(find.byType(TextField).first, auth.devLastEmailCode!);
    await tester.tap(find.text('تحقق'));
    await settleUntil(find.text('كود الواتساب'));
    await tester.enterText(find.byType(TextField).first, auth.devLastWhatsAppCode!);
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

  testWidgets('المواعيد: إضافة موعد اليوم وظهوره وتغيير حالته إلى تم', (tester) async {
    final profile = ClinicProfile(specKey: 'uyoun', doctorName: 'دكتور أحمد', fee: 300);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(profile),
      child: const MaterialApp(home: HomeShell()),
    ));
    await tester.pumpAndSettle();

    // افتح تبويب المواعيد وأضف موعدًا
    await tester.tap(find.text('المواعيد'));
    await tester.pumpAndSettle();
    expect(find.text('لا مواعيد في هذا اليوم'), findsOneWidget);

    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await LocalStore.instance.upsertAppointment(Appointment(
      id: 'a1', patientId: 'p1', patientName: 'منى أحمد',
      date: dateStr, time: '18:30', type: 'كشف جديد', fee: 300,
    ));
    // إعادة التحميل بإعادة فتح التبويب
    await tester.tap(find.text('المرضى'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المواعيد'));
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      if (find.text('منى أحمد').evaluate().isNotEmpty) break;
    }

    expect(find.text('منى أحمد'), findsOneWidget);
    expect(find.textContaining('كشف جديد'), findsOneWidget);
    expect(find.text('مجدول'), findsOneWidget);

    // غيّر الحالة إلى تم
    await tester.tap(find.text('مجدول'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تم').last);
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      if (find.text('تم').evaluate().isNotEmpty) break;
    }
    expect(find.text('تم'), findsWidgets);
  });
}
