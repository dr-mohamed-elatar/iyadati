import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import 'patients_screen.dart';
import 'placeholder_screens.dart';

/// الواجهة الرئيسية بعد اختيار التخصص: كل المحتوى بلغة التخصص المختار
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final spec = app.specialty!;
    final screens = [
      const PatientsScreen(),
      PlaceholderScreen(title: 'المواعيد', icon: Icons.calendar_month, tips: spec.tips),
      PlaceholderScreen(title: 'المال والخدمات', icon: Icons.payments, tips: spec.tips),
      PlaceholderScreen(title: 'الفريق والمخزون', icon: Icons.groups, tips: spec.tips),
      PlaceholderScreen(title: 'النظام', icon: Icons.settings, tips: spec.tips),
    ];
    final labels = ['المرضى', 'المواعيد', 'المال', 'الفريق', 'النظام'];
    final icons = [Icons.people, Icons.calendar_month, Icons.payments, Icons.groups, Icons.settings];

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text(spec.emoji),
          const SizedBox(width: 8),
          Text('عيادة ${spec.name}'),
        ]),
      ),
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (var i = 0; i < labels.length; i++)
            NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ],
      ),
    );
  }
}
