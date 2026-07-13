import 'dart:io';

/// Centralised helper for AdMob IDs.
///
/// During development the Google-provided *test* IDs are used so that
/// real impressions are never accidentally generated.
///
/// Before releasing to production, replace the values below with your
/// actual AdMob ad-unit IDs from the AdMob console.
class AdHelper {
  static bool get isSupportedPlatform {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  // ── Banner Ad Unit IDs ──
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-5648970483808453/3854775633'; // Android production banner
    } else if (Platform.isIOS) {
      return 'ca-app-pub-5648970483808453/9461757319'; // iOS production banner
    }
    return '';
  }
}
