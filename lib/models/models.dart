import 'dart:convert';

/// مريض: بيانات أساسية + حقول التخصص (خريطة مرنة) + قياسات + سجل زيارات
class Patient {
  final String id;
  String name;
  String phone;
  String nationalId; // مشفر عند التخزين
  int? age;
  String gender; // ذكر / أنثى
  String blood;
  String allergies;
  String chronic;
  String notes;
  Map<String, String> specFields; // حقول التخصص (مفتاح الحقل → القيمة)
  DateTime createdAt;

  Patient({
    required this.id,
    required this.name,
    this.phone = '',
    this.nationalId = '',
    this.age,
    this.gender = '',
    this.blood = '',
    this.allergies = '',
    this.chronic = '',
    this.notes = '',
    Map<String, String>? specFields,
    DateTime? createdAt,
  })  : specFields = specFields ?? {},
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'phone': phone, 'national_id': nationalId,
        'age': age, 'gender': gender, 'blood': blood, 'allergies': allergies,
        'chronic': chronic, 'notes': notes,
        'spec_fields': jsonEncode(specFields),
        'created_at': createdAt.toIso8601String(),
      };
  factory Patient.fromMap(Map<String, dynamic> m) => Patient(
        id: m['id'], name: m['name'] ?? '', phone: m['phone'] ?? '',
        nationalId: m['national_id'] ?? '', age: m['age'] as int?,
        gender: m['gender'] ?? '', blood: m['blood'] ?? '',
        allergies: m['allergies'] ?? '', chronic: m['chronic'] ?? '',
        notes: m['notes'] ?? '',
        specFields: Map<String, String>.from(
            (jsonDecode(m['spec_fields'] ?? '{}') as Map).map((k, v) => MapEntry(k as String, '$v'))),
        createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
      );
}

class MeasurementEntry {
  final String id;
  final String patientId;
  final String name;
  final String unit;
  final double value;
  final DateTime date;

  const MeasurementEntry({
    required this.id, required this.patientId, required this.name,
    required this.unit, required this.value, required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'patient_id': patientId, 'name': name, 'unit': unit,
        'value': value, 'date': date.toIso8601String(),
      };
  factory MeasurementEntry.fromMap(Map<String, dynamic> m) => MeasurementEntry(
        id: m['id'], patientId: m['patient_id'], name: m['name'], unit: m['unit'] ?? '',
        value: (m['value'] as num).toDouble(), date: DateTime.parse(m['date']),
      );
}

class Visit {
  final String id;
  final String patientId;
  final DateTime at;
  String type; // من قائمة زيارات التخصص
  String dx; // تشخيص
  String rx; // روشتة
  String note;
  double fee;

  Visit({
    required this.id, required this.patientId, required this.at,
    this.type = '', this.dx = '', this.rx = '', this.note = '', this.fee = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'patient_id': patientId, 'at': at.toIso8601String(),
        'type': type, 'dx': dx, 'rx': rx, 'note': note, 'fee': fee,
      };
  factory Visit.fromMap(Map<String, dynamic> m) => Visit(
        id: m['id'], patientId: m['patient_id'], at: DateTime.parse(m['at']),
        type: m['type'] ?? '', dx: m['dx'] ?? '', rx: m['rx'] ?? '',
        note: m['note'] ?? '', fee: (m['fee'] as num?)?.toDouble() ?? 0,
      );
}

class ServiceItem {
  final String id;
  String name;
  double price;
  ServiceItem({required this.id, required this.name, this.price = 0});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'price': price};
  factory ServiceItem.fromMap(Map<String, dynamic> m) =>
      ServiceItem(id: m['id'], name: m['name'], price: (m['price'] as num?)?.toDouble() ?? 0);
}

/// ملف العيادة: التخصص يُختار مرة واحدة عند إنشاء الحساب ولا تظهر القائمة بعدها
class ClinicProfile {
  String specKey;
  String clinicName;
  String doctorName;
  String address;
  String phone;
  double fee;
  bool open;

  ClinicProfile({
    this.specKey = '',
    this.clinicName = '',
    this.doctorName = '',
    this.address = '',
    this.phone = '',
    this.fee = 0,
    this.open = true,
  });

  bool get hasSpecialty => specKey.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'spec_key': specKey, 'clinic_name': clinicName, 'doctor_name': doctorName,
        'address': address, 'phone': phone, 'fee': fee, 'open': open ? 1 : 0,
      };
  factory ClinicProfile.fromMap(Map<String, dynamic> m) => ClinicProfile(
        specKey: m['spec_key'] ?? '', clinicName: m['clinic_name'] ?? '',
        doctorName: m['doctor_name'] ?? '', address: m['address'] ?? '',
        phone: m['phone'] ?? '', fee: (m['fee'] as num?)?.toDouble() ?? 0,
        open: (m['open'] ?? 1) == 1,
      );
}

/// موعد في جدول العيادة
class Appointment {
  final String id;
  final String patientId;
  String patientName;
  String date; // YYYY-MM-DD
  String time; // HH:mm (24h)
  String type; // نوع الزيارة من تخصص العيادة
  String status; // مجدول | تم | ملغي | لم يحضر
  String note;
  double fee;

  Appointment({
    required this.id, required this.patientId, this.patientName = '',
    required this.date, required this.time,
    this.type = '', this.status = 'مجدول', this.note = '', this.fee = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'patient_id': patientId, 'patient_name': patientName,
        'date': date, 'time': time, 'type': type, 'status': status,
        'note': note, 'fee': fee,
      };
  factory Appointment.fromMap(Map<String, dynamic> m) => Appointment(
        id: m['id'], patientId: m['patient_id'], patientName: m['patient_name'] ?? '',
        date: m['date'], time: m['time'], type: m['type'] ?? '',
        status: m['status'] ?? 'مجدول', note: m['note'] ?? '',
        fee: (m['fee'] as num?)?.toDouble() ?? 0,
      );
}
