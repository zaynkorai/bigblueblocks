# AdMob UMP Consent Integration Plan

This document details the plan to integrate Google's User Messaging Platform (UMP) SDK into the Big Blue Blocks Flutter app to comply with EU/EEA user consent regulations (GDPR).

## Goals
1. **Compliance**: Prompt users in the European Economic Area (EEA), the UK, and Switzerland for consent before serving ads.
2. **Smooth UX**: Defer initialization of the Google Mobile Ads SDK and banner ad requests until the UMP consent flow resolves.
3. **Consent Control**: Provide an option in the "More Settings" dialog to allow users to update their consent preferences at any time.

## Proposed Components

### 1. Consent Manager (`lib/services/consent_manager.dart`)
A singleton class wrapping the UMP SDK API to:
- Request consent updates at startup.
- Automatically load and present the consent form if required.
- Expose status helpers such as `canRequestAds()` and `isPrivacyOptionsRequired()`.
- Show the consent options form when requested by the user.

### 2. Main Entry Point (`lib/main.dart`)
- Defer `MobileAds.instance.initialize()` from `main()` to the `ConsentManager` flow.
- Call `ConsentManager.instance.gatherConsent` after settings are loaded and the native splash screen is dismissed.
- Initialize and load banner ads only if `canRequestAds()` returns true.
- Track whether privacy options are required to toggle the visibility of the privacy preferences menu.

### 3. More Settings Dialog (`lib/settings_dialog.dart`)
- Expose a "Privacy Settings" link if UMP determines that privacy options are required.
- Call `ConsentForm.showPrivacyOptionsForm` to show the consent configuration overlay when clicked.

## Verification
- Validate compilation using `flutter analyze`.
- Test on simulators/devices with `ConsentDebugSettings` simulating an EEA geography to ensure the dialog behaves as expected.
