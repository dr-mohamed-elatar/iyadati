import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/specialties.dart';
import 'config/supabase_config.dart';
import 'models/models.dart';
import 'services/ads_service.dart';
import 'services/auth_service.dart';
import 'services/license_service.dart';
import 'services/local_store.dart';
import 'services/sync_service.dart';
import 'ui/screens/activation_screen.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/registration_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdsService.init();
  await LocalStore.instance.db;
  await SyncService.instance.init();
  final profile = await LocalStore.instance.profile();
  final lic = LicenseService.instance;
  final needsActivation = (await lic.devSecret()) != null && (await lic.current()) == null;
  final auth = SupabaseConfig.enabled ? SupabaseAuthService() : LocalAuthService();
  runApp(IyadatiApp(profile: profile, auth: auth, needsActivation: needsActivation));
}

class AppState extends ChangeNotifier {
  ClinicProfile profile;
  bool activated;
  AppState(this.profile, {this.activated = true});

  void markActivated() {
    activated = true;
    notifyListeners();
  }

  Specialty? get specialty => kSpecialties[profile.specKey];

  Future<void> saveProfile(ClinicProfile pr) async {
    profile = pr;
    await LocalStore.instance.saveProfile(pr);
    notifyListeners();
    // مزامنة خلفية غير حاجبة
    // ignore: unawaited_futures
    SyncService.instance.syncNow();
  }

  Future<void> reloadProfile() async {
    profile = await LocalStore.instance.profile();
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
  final bool needsActivation;
  const IyadatiApp(
      {super.key, required this.profile, required this.auth, this.needsActivation = false});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(profile, activated: !needsActivation),
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
            // بوابة التفعيل أولًا، ثم التخصص/التسجيل
            child: !app.activated
                ? ActivationScreen(onActivated: app.markActivated)
                : app.profile.hasSpecialty
                    ? const HomeShell()
                    : RegistrationScreen(auth: auth),
          ),
        );
      }),
    );
  }
}
