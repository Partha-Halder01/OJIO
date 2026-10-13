import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ojio_mobile/screens/login_screen.dart';
import 'package:ojio_mobile/screens/signup_screen.dart';

void main() {
  for (final signup in [false, true]) {
    for (final size in [
      const Size(280, 568),
      const Size(393, 852),
      const Size(600, 960),
      const Size(852, 393),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${signup ? 'signup' : 'login'} fits $size at $scale', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: signup ? const SignUpScreen() : const LoginScreen(),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final frost = find.byKey(const Key('auth-frosted-form'));
          expect(frost, findsOneWidget);
          expect(tester.widget(frost), isA<BackdropFilter>());
          final panel = tester.widget<Container>(
            find.descendant(of: frost, matching: find.byType(Container)).first,
          );
          final panelGradient =
              (panel.decoration as BoxDecoration).gradient! as LinearGradient;
          expect(
            panelGradient.colors.first.a,
            lessThan(panelGradient.colors.last.a),
          );
          expect(panelGradient.colors.first.a, closeTo(135 / 255, 0.001));
          expect(panelGradient.colors.last.a, lessThan(1));
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Image &&
                  widget.image is AssetImage &&
                  (widget.image as AssetImage).assetName ==
                      'assets/images/google_g.png',
            ),
            findsOneWidget,
          );
          final logo = find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName ==
                    'assets/images/logo_tight.png',
          );
          final fixedLogoRect = tester.getRect(logo);
          expect(find.byType(TextField), findsNWidgets(signup ? 4 : 2));
          final submit = find.widgetWithText(
            ElevatedButton,
            signup ? 'Sign Up' : 'Sign In',
          );
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          expect(tester.getRect(submit).left, greaterThanOrEqualTo(0));
          expect(tester.getRect(submit).right, lessThanOrEqualTo(size.width));
          expect(tester.getRect(logo), fixedLogoRect);
          final footer = find.widgetWithText(
            TextButton,
            signup ? 'Login' : 'Sign Up',
          );
          await tester.ensureVisible(footer);
          await tester.pumpAndSettle();
          expect(tester.getRect(footer).bottom, lessThanOrEqualTo(size.height));
          if (signup) {
            final terms = find.widgetWithText(TextButton, 'T&C');
            expect(terms.hitTestable(), findsOneWidget);
            expect(
              tester.getCenter(terms).dy,
              closeTo(tester.getCenter(footer).dy, 0.1),
            );
            expect(tester.getRect(terms).right, lessThanOrEqualTo(size.width));
          }
          expect(tester.getRect(logo), fixedLogoRect);

          // Keyboard must not cover the password field or prevent reaching submit.
          tester.view.viewInsets = const FakeViewPadding(bottom: 240);
          addTearDown(tester.view.resetViewInsets);
          await tester.pump();
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(tester.getRect(logo), fixedLogoRect);
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Image &&
                  widget.image is AssetImage &&
                  (widget.image as AssetImage).assetName ==
                      'assets/images/auth_background.png',
            ),
            findsOneWidget,
          );
        });
      }
    }
  }

  testWidgets('auth screen back returns to its originating page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SignUpScreen(returnToPrevious: true),
                ),
              ),
              child: const Text('Open signup'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open signup'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open signup'), findsOneWidget);
    expect(find.byType(SignUpScreen), findsNothing);
  });

  testWidgets('switching auth forms preserves return-to-previous intent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen(returnToPrevious: true)),
    );
    final switchButton = find.widgetWithText(TextButton, 'Sign Up');
    await tester.ensureVisible(switchButton);
    await tester.tap(switchButton);
    await tester.pumpAndSettle();
    expect(
      tester.widget<SignUpScreen>(find.byType(SignUpScreen)).returnToPrevious,
      isTrue,
    );
    final loginButton = find.widgetWithText(TextButton, 'Login');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();
    expect(
      tester.widget<LoginScreen>(find.byType(LoginScreen)).returnToPrevious,
      isTrue,
    );
  });
}
