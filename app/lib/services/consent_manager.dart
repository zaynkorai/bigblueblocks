import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:bigblueblocks/services/ad_helper.dart';

/// Singleton wrapper around the Google User Messaging Platform (UMP) SDK.
///
/// Handles GDPR / EEA consent flow:
///   1. Requests consent info update at startup.
///   2. Loads and shows the consent form if consent is required.
///   3. Initialises the Mobile Ads SDK once consent resolves.
///   4. Exposes helpers so the rest of the app can:
///      - Check if ads can be requested ([canRequestAds]).
///      - Check if the privacy options button should be visible
///        ([isPrivacyOptionsRequired]).
///      - Show the privacy options form on demand ([showPrivacyOptionsForm]).
class ConsentManager {
  // ── Singleton ──
  ConsentManager._();
  static final ConsentManager instance = ConsentManager._();

  bool _isMobileAdsInitialized = false;
  ConsentStatus _consentStatus = ConsentStatus.unknown;
  PrivacyOptionsRequirementStatus _privacyOptionsRequirementStatus =
      PrivacyOptionsRequirementStatus.unknown;
  bool _canRequestAds = false;

  /// Whether the Google Mobile Ads SDK has been initialised.
  bool get isMobileAdsInitialized => _isMobileAdsInitialized;

  Future<void> gatherConsent({
    required VoidCallback onConsentComplete,
    bool tagForUnderAgeOfConsent = false,
  }) async {
    if (!AdHelper.isSupportedPlatform) {
      onConsentComplete();
      return;
    }

    if (kDebugMode) {
      debugPrint('UMP: Resetting consent state for debugging.');
      await ConsentInformation.instance.reset();
    }

    final ConsentRequestParameters params;
    if (kDebugMode) {
      params = ConsentRequestParameters(
        tagForUnderAgeOfConsent: tagForUnderAgeOfConsent,
        consentDebugSettings: ConsentDebugSettings(
          debugGeography: DebugGeography.debugGeographyEea,
        ),
      );
    } else {
      params = ConsentRequestParameters(
        tagForUnderAgeOfConsent: tagForUnderAgeOfConsent,
      );
    }

    debugPrint('UMP: Requesting consent info update.');
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        _consentStatus = await ConsentInformation.instance.getConsentStatus();
        _privacyOptionsRequirementStatus = await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus();
        _canRequestAds = await ConsentInformation.instance.canRequestAds();
        debugPrint('UMP: Info update success. Status: $_consentStatus, PrivacyReq: $_privacyOptionsRequirementStatus, CanRequestAds: $_canRequestAds');

        ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
          if (formError != null) {
            debugPrint('UMP: Consent form error: [${formError.errorCode}] ${formError.message}');
          }

          _consentStatus = await ConsentInformation.instance.getConsentStatus();
          _privacyOptionsRequirementStatus = await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus();
          _canRequestAds = await ConsentInformation.instance.canRequestAds();
          debugPrint('UMP: Form completed. New Status: $_consentStatus, New PrivacyReq: $_privacyOptionsRequirementStatus, New CanRequestAds: $_canRequestAds');

          _initMobileAdsIfAllowed(onConsentComplete);
        });
      },
      (error) async {
        debugPrint('UMP: Consent info update failed: [${error.errorCode}] ${error.message}');
        _consentStatus = await ConsentInformation.instance.getConsentStatus();
        _privacyOptionsRequirementStatus = await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus();
        _canRequestAds = await ConsentInformation.instance.canRequestAds();
        debugPrint('UMP: Info update failed. Status: $_consentStatus, PrivacyReq: $_privacyOptionsRequirementStatus, CanRequestAds: $_canRequestAds');

        // Fallback for debug mode to allow ad testing even if UMP update failed
        if (kDebugMode) {
          debugPrint('UMP: Debug mode fallback - enabling ads despite consent info update failure.');
          _canRequestAds = true;
        }

        _initMobileAdsIfAllowed(onConsentComplete);
      },
    );
  }

  /// Returns `true` if the current consent status allows ad requests.
  bool canRequestAds() {
    if (!AdHelper.isSupportedPlatform) return false;
    return _canRequestAds;
  }

  /// Returns `true` when the UMP SDK determines that a privacy options
  /// entry point should be shown (e.g. for EEA users who may want to
  /// update their consent choices).
  bool isPrivacyOptionsRequired() {
    if (!AdHelper.isSupportedPlatform) return false;
    return _privacyOptionsRequirementStatus ==
        PrivacyOptionsRequirementStatus.required;
  }

  /// Presents the privacy / consent options form so the user can update
  /// their choices. Should only be called when [isPrivacyOptionsRequired]
  /// returns `true`.
  void showPrivacyOptionsForm({VoidCallback? onDismissed}) {
    ConsentForm.showPrivacyOptionsForm((formError) async {
      if (formError != null) {
        debugPrint('Privacy options form error: [${formError.errorCode}] ${formError.message}');
      }
      // Refresh status after privacy form interaction
      _consentStatus = await ConsentInformation.instance.getConsentStatus();
      _privacyOptionsRequirementStatus = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      debugPrint('Privacy form completed. Status: $_consentStatus, PrivacyReq: $_privacyOptionsRequirementStatus, CanRequestAds: $_canRequestAds');
      
      // Initialise SDK if consent is now allowed
      _initMobileAdsIfAllowed(() {
        onDismissed?.call();
      });
    });
  }

  // ── Private ──

  void _initMobileAdsIfAllowed(VoidCallback onComplete) {
    if (_isMobileAdsInitialized) {
      onComplete();
      return;
    }

    if (canRequestAds()) {
      MobileAds.instance.initialize().then((_) {
        _isMobileAdsInitialized = true;
        onComplete();
      });
    } else {
      // Consent not granted — don't initialise the ads SDK.
      // The callback is still invoked so the app can proceed.
      onComplete();
    }
  }
}
