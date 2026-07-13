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
  // Google's official test ad unit IDs — safe for development.
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Android test banner
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // iOS test banner
    }
    return '';
  }
}
