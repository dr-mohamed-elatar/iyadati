import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/specialties.dart';
import 'models/models.dart';
import 'services/ads_service.dart';
import 'services/auth_service.dart';
import 'services/local_store.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/registration_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdsService.init();
  await LocalStore.instance.db;
  final profile = await LocalStore.instance.profile();
  runApp(IyadatiApp(profile: profile, auth: LocalAuthService()));
}

class AppState extends ChangeNotifier {
  ClinicProfile profile;
  AppState(this.profile);

  Specialty? get specialty => kSpecialties[profile.specKey];

  Future<void> saveProfile(ClinicProfile pr) async {
    profile = pr;
    await LocalStore.instance.saveProfile(pr);
    notifyListeners();
  }

  Color get themeColor {
    final s = specialty;
    if (s == null) return const Color(0xFF0277BD);
    return Color(int.parse('FF${s.color.substring(1)}', radix: 16));
  }
}

class IyadatiApp extends StatelessWidget {
  final ClinicProfile profile;
  final AuthService auth;
  const IyadatiApp({super.key, required this.profile, required this.auth});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(profile),
      child: Consumer<AppState>(builder: (ctx, app, __) {
        return MaterialApp(
          title: 'عيادتي',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: app.themeColor),
          ),
          home: Directionality(
            textDirection: TextDirection.rtl,
            // قائمة التخصصات تظهر فقط عند إنشاء الحساب (profile بلا تخصص)
            child: app.profile.hasSpecialty
                ? const HomeShell()
                : RegistrationScreen(auth: auth),
          ),
        );
      }),
    );
  }
}
