import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;

import '../../main.dart';
import '../../services/ads_service.dart';
import 'appointments_screen.dart';
import 'finance_screen.dart';
import 'patients_screen.dart';
import 'placeholder_screens.dart';
import 'settings_screen.dart';

/// الواجهة الرئيسية بعد اختيار التخصص: كل المحتوى بلغة التخصص المختار
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _apptKey = GlobalKey<AppointmentsScreenState>();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final spec = app.specialty!;
    final screens = [
      const PatientsScreen(),
      AppointmentsScreen(key: _apptKey),
      const FinanceScreen(),
      PlaceholderScreen(title: 'الفريق والمخزون', icon: Icons.groups, tips: spec.tips),
      SettingsScreen(tips: spec.tips),
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
      floatingActionButton: _index == 1 ? AppointmentsFab(stateKey: _apptKey) : null, // المال له FAB خاص
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const AdBanner(),
        NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (var i = 0; i < labels.length; i++)
              NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
          ],
        ),
      ]),
    );
  }
}

/// بانر إعلاني (اختباري) أسفل الشاشة الرئيسية - لا يظهر على الويب أو في الاختبارات
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});
  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (AdsService.supported) {
      _ad = AdsService.createBanner(() => setState(() => _loaded = true));
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return SizedBox(height: 50, width: double.infinity, child: AdWidget(ad: _ad!));
  }
}
