import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ojio_mobile/screens/welcome_screen.dart';

void main() {
  for (final size in [
    const Size(280, 568),
    const Size(320, 568),
    const Size(393, 852),
    const Size(600, 960),
    const Size(852, 393),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('welcome fits $size at text scale $scale', (tester) async {
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
            home: const WelcomeScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final background = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/welcome_background.png',
        );
        expect(tester.getRect(background), Offset.zero & size);

        final create = find.widgetWithText(ElevatedButton, 'Create Account');
        final login = find.widgetWithText(OutlinedButton, 'Log In');
        await tester.ensureVisible(create);
        await tester.pumpAndSettle();
        final createRect = tester.getRect(create);
        final loginRect = tester.getRect(login);
        expect(createRect.top, closeTo(loginRect.top, 0.1));
        expect(createRect.width, closeTo(loginRect.width, 0.1));
        expect(createRect.height, closeTo(loginRect.height, 0.1));
        expect(createRect.right, lessThan(loginRect.left));
        expect(createRect.left, greaterThanOrEqualTo(0));
        expect(loginRect.right, lessThanOrEqualTo(size.width));
        expect(createRect.height, greaterThanOrEqualTo(48));
        expect(loginRect.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName ==
                    'assets/images/welcome_background.png',
          ),
          findsOneWidget,
        );
      });
    }
  }
}
