import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ojio_mobile/main.dart';

void main() {
  for (final size in [
    const Size(240, 320),
    const Size(320, 568),
    const Size(393, 852),
    const Size(768, 1024),
    const Size(1024, 240),
  ]) {
    testWidgets(
      'splash logo stays inside safe bounds throughout animation $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const insets = EdgeInsets.fromLTRB(12, 44, 12, 24);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: insets),
              child: child!,
            ),
            home: const SplashScreen(),
          ),
        );
        for (final milliseconds in [0, 300, 600, 900]) {
          await tester.pump(Duration(milliseconds: milliseconds));
          expect(tester.takeException(), isNull);
          final rect = tester.getRect(find.byKey(const Key('splash-logo')));
          expect(rect.left, greaterThanOrEqualTo(insets.left + 24));
          expect(rect.right, lessThanOrEqualTo(size.width - insets.right - 24));
          expect(rect.top, greaterThanOrEqualTo(insets.top + 24));
          expect(
            rect.bottom,
            lessThanOrEqualTo(size.height - insets.bottom - 24),
          );
          expect(rect.width / rect.height, closeTo(475 / 180, 0.001));
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }
}
