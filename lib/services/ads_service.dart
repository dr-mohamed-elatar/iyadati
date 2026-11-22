import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;

/// إعلانات AdMob: معرّفات اختبار رسمية من Google حتى يُفعَّل حساب AdMob الحقيقي.
/// الاستبدال لاحقًا: ضع معرّف التطبيق الحقيقي في AndroidManifest ومعرّف الوحدة هنا.
class AdsService {
  /// معرّف تطبيق AdMob الاختباري (يُستخدم أيضًا في AndroidManifest.xml)
  static const String testAppId = 'ca-app-pub-3940256099942544~1452512354';
  /// معرّف وحدة البانر الاختبارية
  static const String testBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';

  static bool get supported => !kIsWeb;

  static Future<void> init() async {
    if (!supported) return;
    await MobileAds.instance.initialize();
  }

  static BannerAd? createBanner(void Function() onLoaded) {
    if (!supported) return null;
    final ad = BannerAd(
      adUnitId: testBannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(onAdLoaded: (_) => onLoaded()),
    );
    ad.load();
    return ad;
  }
}
