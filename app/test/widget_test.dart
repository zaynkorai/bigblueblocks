import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bigblueblocks/main.dart';
import 'package:bigblueblocks/terms_consent_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BigBlueBlocksApp(hasAcceptedTerms: true));
    await tester.pump();

    // Verify the start screen renders
    expect(find.text('SCORE'), findsOneWidget);
  });

  testWidgets('Terms consent screen flow test', (WidgetTester tester) async {
    bool onAcceptedCalled = false;
    await tester.pumpWidget(MaterialApp(
      home: TermsConsentScreen(
        onAccepted: () {
          onAcceptedCalled = true;
        },
      ),
    ));
    await tester.pump();

    // Verify Terms Consent Screen elements
    expect(
      find.byWidgetPredicate((widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains('Please read and agree to our Terms of Service and Privacy Policy')),
      findsOneWidget,
    );
    expect(find.text('ACCEPT'), findsOneWidget);

    // Tap ACCEPT button
    await tester.tap(find.text('ACCEPT'));
    await tester.pump();

    // Verify callback is called
    expect(onAcceptedCalled, isTrue);
  });
}
