import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ojio_mobile/main.dart';
import 'package:ojio_mobile/models/models.dart';
import 'package:ojio_mobile/screens/about_ojio_screen.dart';
import 'package:ojio_mobile/screens/legal_document_screen.dart';
import 'package:ojio_mobile/services/auth_service.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('About opens both documents and returns to About', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutOjioScreen()));
    expect(find.text('Open Source Licenses'), findsNothing);
    for (final document in LegalDocument.values) {
      final link = find.text(document.title);
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byType(LegalDocumentScreen), findsOneWidget);
      expect(find.text(document.title), findsOneWidget);
      expect(find.textContaining('Draft for client review'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AboutOjioScreen), findsOneWidget);
    }
  });

  for (final document in LegalDocument.values) {
    testWidgets(
      '${document.title} scrolls on a narrow screen with large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: LegalDocumentScreen(document: document),
          ),
        );
        await tester.pumpAndSettle();
        final lastSection = find.text(
          document == LegalDocument.terms
              ? '10. Questions and updates'
              : '10. Your choices and questions',
        );
        await tester.ensureVisible(lastSection);
        await tester.pumpAndSettle();
        expect(lastSection.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Profile keeps About but removes the duplicate privacy entry', (
    tester,
  ) async {
    AuthService().token = 'test-token';
    AuthService().currentUser = UserModel.fromJson({
      'id': 7,
      'name': 'Test Seller',
      'email': 'test@example.com',
      'phone': '9876543210',
    });
    addTearDown(() {
      AuthService().token = null;
      AuthService().currentUser = null;
    });
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          final app = const OjioApp().build(context) as MaterialApp;
          return MaterialApp(theme: app.theme, home: const ProfileScreen());
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Privacy & Safety'), findsNothing);
    expect(find.text('Privacy Policy'), findsNothing);
    final about = find.text('About OJIO');
    await tester.ensureVisible(about);
    await tester.tap(about);
    await tester.pumpAndSettle();
    expect(find.byType(AboutOjioScreen), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
