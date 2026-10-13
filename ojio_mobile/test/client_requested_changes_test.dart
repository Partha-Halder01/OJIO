import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ojio_mobile/core/home_preview.dart';
import 'package:ojio_mobile/core/theme.dart';
import 'package:ojio_mobile/main.dart';
import 'package:ojio_mobile/models/models.dart';
import 'package:ojio_mobile/screens/signup_screen.dart';
import 'package:ojio_mobile/screens/search_screen.dart';
import 'package:ojio_mobile/screens/my_ads_screen.dart';
import 'package:ojio_mobile/screens/legal_document_screen.dart';
import 'package:ojio_mobile/screens/welcome_screen.dart';
import 'package:ojio_mobile/screens/wallet_screen.dart';
import 'package:ojio_mobile/services/api_service.dart';
import 'package:ojio_mobile/services/auth_service.dart';
import 'package:ojio_mobile/widgets/paywall_modal.dart';
import 'feed_and_api_test.dart' show pixel;

class ClientChangesApi extends ApiService {
  final registrations = <String?>[];
  final searches = <String?>[];
  final suggestions = <String>[];
  final pendingSuggestions = <String, Completer<List<String>>>{};
  int balance = 0;
  int walletPayments = 0;
  @override
  Future<Map<String, dynamic>?> register(
    String name,
    String email,
    String password, {
    String? phone,
  }) async {
    registrations.add(phone);
    return {
      'status': 'success',
      'token': 'signup-token',
      'user': {'id': 7, 'name': name, 'email': email, 'phone': phone},
    };
  }

  @override
  Future<Map<String, dynamic>> updateProfileDetails(
    String name,
    String phone,
  ) async => {
    'status': 'success',
    'user': {'id': 7, 'name': name, 'phone': phone},
  };
  @override
  Future<Map<String, dynamic>> fetchLegalDocument(String slug) async => {
    'slug': slug,
    'title': slug == 'terms' ? 'Terms & Conditions' : 'Privacy Policy',
    'content':
        'Client-approved marketplace content for $slug. Please use OJIO responsibly.',
    'is_draft': false,
  };
  @override
  Future<List<CategoryModel>> fetchCategories() async => [
    CategoryModel(id: 1, name: 'Cars', slug: 'cars'),
    CategoryModel(id: 2, name: 'Electronics & Appliances', slug: 'electronics'),
    CategoryModel(id: 3, name: 'Furniture', slug: 'furniture'),
  ];
  @override
  Future<List<ListingModel>> fetchListings({
    int? categoryId,
    String? city,
    String? query,
    double? latitude,
    double? longitude,
    double radius = 50,
    String? feed,
    int page = 1,
    double? minPrice,
    double? maxPrice,
    bool throwOnError = false,
  }) async {
    searches.add(query);
    return List.generate(
      2,
      (i) => ListingModel(
        id: i + 1,
        title: 'Result $query $i',
        price: 100,
        city: 'Kolkata',
        images: [pixel],
        createdAt: DateTime(2026),
      ),
    );
  }

  @override
  Future<List<String>> fetchSearchSuggestions(
    String query, {
    int? categoryId,
    String? city,
    double? latitude,
    double? longitude,
    double radius = 50,
  }) async {
    suggestions.add(query);
    return pendingSuggestions[query]?.future ?? Future.value(['Phone 128GB']);
  }

  @override
  Future<Map<String, dynamic>> fetchMyAdsSnapshot() async => {
    'data': <Map<String, dynamic>>[],
  };
  @override
  Future<List<PremiumPackageModel>> fetchPackages() async => [
    PremiumPackageModel(
      id: 1,
      key: 'single',
      name: 'Per ad',
      price: 48,
      adsLimit: 1,
      durationDays: 0,
    ),
  ];
  @override
  Future<Map<String, dynamic>> wallet() async => {
    'balance_paise': balance,
    'transactions': [],
    'pending_payments': [],
  };
  @override
  Future<Map<String, dynamic>> payWithWallet(
    int packageId,
    String requestId, {
    String? couponCode,
  }) async {
    walletPayments++;
    return {};
  }
}

void main() {
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    AuthService().onLogout = null;
    await AuthService().logout();
    globalLatitude = null;
    globalLongitude = null;
  });
  tearDown(() async => AuthService().logout());

  test('Home previews are capped at six and always contain complete rows', () {
    for (var count = 0; count < 22; count++) {
      final all = List.generate(count, (i) => i);
      final preview = homePreviewItems(all);
      expect(preview.length, lessThanOrEqualTo(6));
      expect(preview.length.isEven, isTrue);
      expect(all.length, count);
      expect(preview, all.take(preview.length));
    }
  });

  testWidgets('Welcome has no guest entry or promotional feature chips', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Browse as Guest'), findsNothing);
    expect(find.text('Verified Sellers'), findsNothing);
    expect(find.text('Find nearby'), findsOneWidget);
    final app =
        const OjioApp().build(tester.element(find.byType(WelcomeScreen)))
            as MaterialApp;
    expect(
      app.routes!['/home']!(tester.element(find.byType(WelcomeScreen))),
      isA<WelcomeScreen>(),
    );
  });

  testWidgets('signup submits contact with registration and skips setup', (
    tester,
  ) async {
    final api = ClientChangesApi();
    bool? completed;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                completed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SignUpScreen(api: api, returnToPrevious: true),
                  ),
                );
              },
              child: const Text('Origin'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Origin'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Seller');
    await tester.enterText(find.byType(TextField).at(1), 'seller@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'Password123');
    await tester.enterText(
      find.byKey(const ValueKey('signup-phone')),
      '9876543210',
    );
    final submit = find.widgetWithText(ElevatedButton, 'Sign Up');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(api.registrations, ['9876543210']);
    expect(completed, isTrue);
    expect(AuthService().currentUser?.phone, '9876543210');
    expect(find.text('Complete Your Profile'), findsNothing);
  });

  testWidgets('signup rejects missing phone before contacting server', (
    tester,
  ) async {
    final api = ClientChangesApi();
    await tester.pumpWidget(MaterialApp(home: SignUpScreen(api: api)));
    for (final entry in [
      'Seller',
      'seller@example.com',
      'Password123',
    ].indexed) {
      await tester.enterText(find.byType(TextField).at(entry.$1), entry.$2);
    }
    final submit = find.widgetWithText(ElevatedButton, 'Sign Up');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(api.registrations, isEmpty);
    expect(find.text('Enter a valid 10-digit mobile number.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('signup T&C sits beside login and opens admin content', (
    tester,
  ) async {
    final api = ClientChangesApi();
    await tester.pumpWidget(MaterialApp(home: SignUpScreen(api: api)));
    final link = find.widgetWithText(TextButton, 'T&C');
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    final login = find.widgetWithText(TextButton, 'Login');
    expect(tester.getCenter(link).dy, closeTo(tester.getCenter(login).dy, 0.1));
    expect(
      tester.getRect(link).left,
      greaterThanOrEqualTo(tester.getRect(login).right),
    );
    expect(
      tester.getCenter(link).dx,
      greaterThan(
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
      ),
    );
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(
      find.textContaining('Client-approved marketplace content'),
      findsOneWidget,
    );
    expect(find.textContaining('Draft for client review'), findsNothing);
  });

  testWidgets(
    'Google contact is completed in signup without registering again',
    (tester) async {
      final api = ClientChangesApi();
      await AuthService().setAuth('google-token', {'id': 7, 'name': 'Seller'});
      await tester.pumpWidget(
        MaterialApp(
          home: SignUpScreen(
            api: api,
            completeContact: true,
            returnToPrevious: true,
          ),
        ),
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Complete Your Profile'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('signup-phone')),
        '9876543210',
      );
      final submit = find.widgetWithText(ElevatedButton, 'Complete Account');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.registrations, isEmpty);
      expect(AuthService().currentUser?.phone, '9876543210');
    },
  );

  testWidgets(
    'typing suggests, clicking Search submits, selecting suggestion searches',
    (tester) async {
      final api = ClientChangesApi();
      await tester.pumpWidget(
        MaterialApp(
          home: SearchExploreScreen(currentCity: 'Kolkata', api: api),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Phone');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(api.suggestions, ['Phone']);
      expect(find.text('Phone 128GB'), findsOneWidget);
      expect(api.searches.last, '');
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      expect(api.searches.last, 'Phone');
      expect(find.byKey(const ValueKey('search-suggestions')), findsNothing);
      await tester.enterText(find.byType(TextField), 'Phone new');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Phone 128GB'));
      await tester.pumpAndSettle();
      expect(api.searches.last, 'Phone 128GB');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('older suggestion response cannot replace a newer query', (
    tester,
  ) async {
    final api = ClientChangesApi();
    api.pendingSuggestions['Ca'] = Completer<List<String>>();
    api.pendingSuggestions['Car'] = Completer<List<String>>();
    await tester.pumpWidget(
      MaterialApp(
        home: SearchExploreScreen(currentCity: 'Kolkata', api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ca');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'Car');
    await tester.pump(const Duration(milliseconds: 400));
    api.pendingSuggestions['Car']!.complete(['Car new']);
    await tester.pumpAndSettle();
    api.pendingSuggestions['Ca']!.complete(['Car old']);
    await tester.pumpAndSettle();
    expect(find.text('Car new'), findsOneWidget);
    expect(find.text('Car old'), findsNothing);
  });

  testWidgets(
    'suggestions remain usable above the keyboard on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          home: SearchExploreScreen(
            currentCity: 'Kolkata',
            api: ClientChangesApi(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Phone');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final suggestion = find.text('Phone 128GB');
      expect(suggestion.hitTestable(), findsOneWidget);
      expect(tester.getRect(suggestion).bottom, lessThan(328));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Profile separates phone and city with @', (tester) async {
    await AuthService().setAuth('token', {
      'id': 7,
      'name': 'Seller',
      'phone': '9876543210',
      'city': 'Kolkata',
    });
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.text('9876543210  @  Kolkata'), findsOneWidget);
  });

  testWidgets(
    'category centres have equal spacing despite different label lengths',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SearchExploreScreen(
            currentCity: 'Kolkata',
            api: ClientChangesApi(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final centres = [
        'All',
        'Cars',
        'Electronics & Appliances',
        'Furniture',
      ].map((name) => tester.getCenter(find.text(name)).dx).toList();
      expect(centres[1] - centres[0], closeTo(centres[2] - centres[1], 0.1));
      expect(centres[2] - centres[1], closeTo(centres[3] - centres[2], 0.1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('My Ads Rejected tab is reachable on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: MyAdsScreen(api: ClientChangesApi())),
    );
    await tester.pumpAndSettle();
    final rejected = find.text('Rejected (0)');
    await tester.ensureVisible(rejected);
    await tester.tap(rejected);
    await tester.pumpAndSettle();
    expect(rejected.hitTestable(), findsOneWidget);
    expect(tester.getRect(rejected).right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppColors.background,
    );
  });

  testWidgets('insufficient wallet balance opens top-up instead of charging', (
    tester,
  ) async {
    final api = ClientChangesApi();
    await AuthService().setAuth('token', {
      'id': 7,
      'name': 'Seller',
      'phone': '9876543210',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaywallModal(api: api, onPaymentSuccess: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('by UPI or cards'), findsOneWidget);
    expect(find.textContaining('with Razorpay'), findsNothing);
    final add = find.widgetWithText(FilledButton, 'Add money to wallet');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.byType(WalletScreen), findsOneWidget);
    expect(api.walletPayments, 0);
    api.balance = 5000;
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FilledButton, 'Pay ₹48.00 from wallet'),
      findsOneWidget,
    );
  });

  test('both Android launch themes hide the native launcher icon', () {
    for (final variant in ['values-v31', 'values-night-v31']) {
      final xml = File(
        'android/app/src/main/res/$variant/styles.xml',
      ).readAsStringSync();
      expect(xml, contains('@drawable/transparent_icon'));
      expect(xml, contains('android:windowSplashScreenIconBackgroundColor'));
    }
  });
}
