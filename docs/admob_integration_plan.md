# AdMob Integration Plan (Bottom Banner)

This document outlines the step-by-step process for integrating a standard Google AdMob banner (`320x50`) at the safe bottom edge of the Big Blue Blocks app.

## 1. Add the Package Dependency
Run the following command from within the `app` directory to install the official Google Mobile Ads package:
```bash
flutter pub add google_mobile_ads
```

## 2. Platform Setup (OS Configurations)
Before initializing the ads, ensure your application IDs are registered in the native platform files.

### Android
Add your AdMob App ID to your `android/app/src/main/AndroidManifest.xml` inside the `<application>` tag:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy"/> <!-- Replace with real Android App ID -->
```

### iOS
Add your AdMob App ID to your `ios/Runner/Info.plist`:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-xxxxxxxxxxxxxxxx~zzzzzzzzzz</string> <!-- Replace with real iOS App ID -->
```

## 3. Initialize AdMob globally
In your `app/lib/main.dart`, import the Ads package and initialize the SDK before running the app.
```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Google Mobile Ads SDK
  MobileAds.instance.initialize();
  
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // ... other setups
  runApp(const BigBlueBlocksApp());
}
```

## 4. Load the Banner Ad logically
Inside `_GameScreenState`, manage the loading of the ad:
```dart
BannerAd? _bannerAd;
bool _isAdLoaded = false;

// NOTE: Use test IDs during development to avoid account penalties.
final String _adUnitId = 'ca-app-pub-3940256099942544/6300978111'; 

@override
void initState() {
  super.initState();
  _loadAd();
}

void _loadAd() {
  _bannerAd = BannerAd(
    adUnitId: _adUnitId,
    size: AdSize.banner,
    request: const AdRequest(),
    listener: BannerAdListener(
      onAdLoaded: (ad) {
        setState(() {
          _isAdLoaded = true;
        });
      },
      onAdFailedToLoad: (ad, error) {
        debugPrint('BannerAd failed to load: $error');
        ad.dispose();
      },
    ),
  )..load();
}

@override
void dispose() {
  _bannerAd?.dispose();
  super.dispose();
}
```

## 5. Implement the UI Placeholder
In `_GameScreenState`'s `build` method, attach the ad to the `Scaffold`'s `bottomNavigationBar`. This anchors it perfectly at the bottom without shifting game physics.

```dart
    return Scaffold(
      backgroundColor: bgDarkBlue,
      // The Ad Banner is placed safely at the absolute bottom
      bottomNavigationBar: _isAdLoaded && _bannerAd != null
          ? Container(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              alignment: Alignment.center,
              child: AdWidget(ad: _bannerAd!),
            )
          : const SizedBox.shrink(),
          
      body: SafeArea(
        child: Stack(
          // Game content remains intact
```
