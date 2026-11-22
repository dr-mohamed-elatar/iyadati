import 'package:flutter/material.dart';

/// شاشات مؤقتة للأقسام قيد البناء — تعرض نصائح التخصص حتى تكتمل
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> tips;
  const PlaceholderScreen({super.key, required this.title, required this.icon, required this.tips});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Icon(icon, size: 48, color: Colors.grey),
      const SizedBox(height: 8),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      const Text('قيد البناء في النسخة القادمة', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      const Divider(height: 32),
      const Text('نصائح تخصصك:', style: TextStyle(fontWeight: FontWeight.bold)),
      ...tips.map((t) => ListTile(leading: const Icon(Icons.tips_and_updates, color: Colors.amber), title: Text(t))),
    ]);
  }
}
