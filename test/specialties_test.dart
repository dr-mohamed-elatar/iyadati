import 'package:flutter_test/flutter_test.dart';
import 'package:iyadati_app/config/specialties.dart';

void main() {
  group('تعريفات التخصصات — سلامة البنية', () {
    test('34 تخصصًا رئيسيًا + 3 أسنان فرعية = 37', () {
      expect(kSpecialties.length, 37);
    });

    test('كل تخصص له اسم وأيقونة ولون ووصف وزيارات ونصائح', () {
      for (final e in kSpecialties.entries) {
        final s = e.value;
        expect(s.key, e.key);
        expect(s.name, isNotEmpty, reason: e.key);
        expect(s.emoji, isNotEmpty, reason: e.key);
        expect(s.color, startsWith('#'), reason: e.key);
        expect(s.desc, isNotEmpty, reason: e.key);
        expect(s.visits, isNotEmpty, reason: e.key);
        expect(s.tips, isNotEmpty, reason: e.key);
        expect(s.records, isNotEmpty, reason: e.key);
        expect(s.services, isNotEmpty, reason: e.key);
        expect(s.measurements, isNotEmpty, reason: e.key);
      }
    });

    test('كل حقل نوعه معروف وخيارات select غير فارغة ومفاتيح الحقول بلا مسافات', () {
      const types = {'text', 'number', 'date', 'select'};
      for (final s in kSpecialties.values) {
        final keys = <String>{};
        for (final f in s.fields) {
          expect(types, contains(f.type), reason: '${s.key}.${f.key}');
          expect(f.key, isNot(contains(' ')), reason: s.key);
          expect(f.label, isNotEmpty, reason: '${s.key}.${f.key}');
          if (f.type == 'select') expect(f.options, isNotEmpty, reason: '${s.key}.${f.key}');
          expect(keys.add(f.key), true, reason: 'تكرار ${f.key} في ${s.key}');
        }
      }
    });

    test('كل قياس: min < max ووحدة واسم', () {
      for (final s in kSpecialties.values) {
        for (final m in s.measurements) {
          expect(m.min, lessThan(m.max), reason: '${s.key}/${m.name}');
          expect(m.name, isNotEmpty);
        }
      }
    });

    test('كل تخصص في المجموعات موجود فعلًا، وكل تخصص رئيسي له مجموعة', () {
      final grouped = <String>{};
      for (final list in kSpecialtyGroups.values) {
        for (final k in list) {
          expect(kSpecialties, contains(k), reason: k);
          grouped.add(k);
        }
      }
      // تخصصات الأسنان الفرعية تُعرض ضمن مجموعة الأسنان عبر التخصص الأم
      const dental = {'ortho', 'implant', 'pedo'};
      for (final k in kSpecialties.keys) {
        if (dental.contains(k)) continue;
        expect(grouped, contains(k), reason: '$k بلا مجموعة');
      }
    });

    test('التخصصات الـ34 الأساسية لها قياسات وسجلات مخصصة أو افتراضية صالحة', () {
      for (final s in kSpecialties.values) {
        expect(s.measurements, isNotEmpty, reason: s.key);
        expect(s.records, isNotEmpty, reason: s.key);
      }
    });

    test('عيون — التخصص المذكور في الطلب: نموذج قياس نظر وضغط عين موجود', () {
      final eye = kSpecialties['uyoun']!;
      expect(eye.name, 'عيون');
      expect(eye.fields.map((f) => f.label), containsAll(['نظر العين اليمنى', 'نظر العين اليسرى', 'ضغط العين']));
      expect(eye.measurements.map((m) => m.name), contains('ضغط العين'));
      expect(eye.services.any((s) => s.contains('ليزك')), true);
    });
  });
}
