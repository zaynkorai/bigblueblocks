import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:bigblueblocks/main.dart';

class TermsConsentScreen extends StatefulWidget {
  final VoidCallback onAccepted;

  const TermsConsentScreen({
    super.key,
    required this.onAccepted,
  });

  @override
  State<TermsConsentScreen> createState() => _TermsConsentScreenState();
}

class _TermsConsentScreenState extends State<TermsConsentScreen>
    with SingleTickerProviderStateMixin {
  late TapGestureRecognizer _termsRecognizer;
  late TapGestureRecognizer _privacyRecognizer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Guarantee that the native splash screen is dismissed when this screen loads.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _launchUrl('https://bigblueblocks.app/terms.html');
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _launchUrl('https://bigblueblocks.app/privacy.html');

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch $urlString');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final layout = GameLayout(
      screenWidth: mq.size.width,
      screenHeight: mq.size.height,
      safeTop: mq.padding.top,
      safeBottom: mq.padding.bottom,
    );

    final baseTextStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: fontWhite.withValues(alpha: 0.85),
          fontSize: layout.fontMd,
          height: 1.6,
        ) ??
        TextStyle(
          color: fontWhite.withValues(alpha: 0.85),
          fontSize: layout.fontMd,
          height: 1.6,
        );

    return Scaffold(
      backgroundColor: bgDarkBlue,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: (layout.screenWidth * 0.08).clamp(16.0, 40.0),
                vertical: 24.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Text with inline links above the Accept button
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: baseTextStyle,
                      children: [
                        const TextSpan(
                          text: "Welcome to Big Blue Blocks",
                        ),
                        const TextSpan(
                          text: "Please read and accept to our ",
                        ),
                        TextSpan(
                          text: "Terms of Service",
                          style: const TextStyle(
                            color: gameYellow,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: gameYellow,
                            decorationThickness: 1.5,
                          ),
                          recognizer: _termsRecognizer,
                        ),
                        const TextSpan(
                          text: " and ",
                        ),
                        TextSpan(
                          text: "Privacy Policy",
                          style: const TextStyle(
                            color: gameYellow,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: gameYellow,
                            decorationThickness: 1.5,
                          ),
                          recognizer: _privacyRecognizer,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Pulsing Accept Button
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      double s = 1.0 + (_pulseController.value * 0.025);
                      return Transform.scale(scale: s, child: child);
                    },
                    child: SizedBox(
                      width: layout.buttonWidth,
                      child: ElevatedButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('hasAcceptedTerms', true);
                          widget.onAccepted();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gameYellow,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: layout.buttonPadV),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: Text(
                          "ACCEPT",
                          style: TextStyle(
                            color: bgDarkBlue,
                            fontSize: layout.buttonFontSize,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
