import 'widgets/app_notice.dart';
import 'widgets/premium_badge.dart';
import 'screens/premium_preview_screen.dart';
import 'screens/marketplace_feed_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';
import 'services/chat_unread_service.dart';
import 'services/my_ads_updates_service.dart';
import 'services/push_notifications_service.dart';
import 'widgets/admob_banner_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'core/marketplace_location.dart';
import 'core/api_config.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'core/theme.dart';
import 'models/models.dart';
import 'services/api_service.dart';

import 'widgets/listing_card.dart';
import 'screens/post_ad_screen.dart';
import 'widgets/paywall_modal.dart';
import 'screens/chat_screen.dart';
import 'screens/my_ads_screen.dart';
import 'screens/search_screen.dart';

import 'screens/welcome_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/city_location_screen.dart';
import 'screens/notifications_settings_screen.dart';
import 'screens/help_support_screen.dart';
import 'screens/about_ojio_screen.dart';
import 'services/auth_service.dart';
import 'core/home_preview.dart';
import 'screens/login_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/signup_screen.dart';

double? globalLatitude;
double? globalLongitude;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationsService.instance.initialize();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('AdMob init error: $e');
    }
  }
  runApp(const OjioApp());
}

class OjioApp extends StatelessWidget {
  const OjioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OJIO',
      navigatorKey: PushNotificationsService.instance.navigatorKey,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [AppNoticeObserver()],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        textTheme: GoogleFonts.outfitTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.card,
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => !AuthService().isAuthenticated
            ? const WelcomeScreen()
            : MainNavigationScreen(
                initialCity: AuthService().currentUser?.city ?? 'Kolkata',
              ),
        '/welcome': (context) => const WelcomeScreen(),
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final String initialCity;
  const MainNavigationScreen({super.key, this.initialCity = 'Kolkata'});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _visitedTabs = <int>{0};
  final _tabHistory = <int>[0];
  Timer? _unreadTimer;
  late String _currentCity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) PushNotificationsService.instance.appReady();
    });
    ChatUnreadService.instance.refresh();
    MyAdsUpdatesService.instance.refresh();
    _unreadTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        ChatUnreadService.instance.refresh();
        MyAdsUpdatesService.instance.refresh();
      }
    });
    _currentCity = widget.initialCity;
    AuthService().location.addListener(_locationChanged);
    _restoreLocation();
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    AuthService().location.removeListener(_locationChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ChatUnreadService.instance.refresh();
      MyAdsUpdatesService.instance.refresh();
    }
  }

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    AppNotice.dismiss();
    setState(() {
      _visitedTabs.add(index);
      _tabHistory.add(index);
      _currentIndex = index;
    });
    ChatUnreadService.instance.refresh();
  }

  Future<void> _restoreLocation() async {
    await AuthService().restoreLocation(fallbackCity: _currentCity);
  }

  void _locationChanged() {
    final location = AuthService().location.value;
    if (!mounted || location == null) return;
    setState(() {
      _currentCity = location.city;
      globalLatitude = location.latitude;
      globalLongitude = location.longitude;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        currentCity: _currentCity,
        onCitySelectTap: () => _openLocationPicker(context),
        onProfileTap: () => _selectTab(4),
      ),
      _visitedTabs.contains(1)
          ? ChatScreen(active: _currentIndex == 1)
          : const SizedBox.shrink(),
      const SizedBox.shrink(),
      _visitedTabs.contains(3)
          ? MyAdsScreen(active: _currentIndex == 3)
          : const SizedBox.shrink(),
      _visitedTabs.contains(4)
          ? const ProfileScreen()
          : const SizedBox.shrink(),
    ];

    return PopScope(
      canPop: _tabHistory.length == 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _tabHistory.length > 1) {
          AppNotice.dismiss();
          setState(() {
            _tabHistory.removeLast();
            _currentIndex = _tabHistory.last;
          });
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: screens),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) async {
              if (index == 2) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PostAdScreen()),
                );
              } else {
                _selectTab(index);
              }
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.background,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textSecondary,
            selectedLabelStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
            unselectedLabelStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            elevation: 0,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_filled),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: ValueListenableBuilder<int>(
                  valueListenable: ChatUnreadService.instance,
                  builder: (_, count, child) => Badge(
                    isLabelVisible: count > 0,
                    label: Text(count > 99 ? '99+' : '$count'),
                    child: const Icon(Icons.chat_bubble_outline_rounded),
                  ),
                ),
                label: 'Chats',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF087CF5).withAlpha(100),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                label: 'Sell',
              ),
              BottomNavigationBarItem(
                icon: ValueListenableBuilder<bool>(
                  valueListenable: MyAdsUpdatesService.instance,
                  builder: (_, unread, child) => Badge(
                    isLabelVisible: unread,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.list_alt_rounded),
                  ),
                ),
                label: 'My Ads',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLocationPicker(BuildContext context) async {
    final location = await Navigator.push<MarketplaceLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationSelectScreen(returnSelection: true),
      ),
    );
    if (location != null && mounted) {
      setState(() => _currentCity = location.city);
    }
  }
}

class HomeScreen extends StatefulWidget {
  final ApiService? api;
  final String currentCity;
  final VoidCallback onCitySelectTap;
  final VoidCallback? onProfileTap;

  const HomeScreen({
    super.key,
    required this.currentCity,
    required this.onCitySelectTap,
    this.onProfileTap,
    this.api,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _recommendedKey = GlobalKey();
  final _nearbyKey = GlobalKey();

  late final ApiService _api;
  List<ListingModel> _listings = [];
  List<ListingModel> _nearbyListings = [];
  int _feedRequest = 0;
  double? _loadedLatitude;
  double? _loadedLongitude;
  String? _feedError;
  final Map<String, String> _feedFailures = {};
  bool _recommendedLoading = true;
  bool _nearbyLoading = true;
  String? _loadedCity;
  bool _isLoading = true;
  int? _homeSelectedCategoryId;
  String? _homeSelectedCategoryName;

  List<ListingModel> get _displayedListings {
    return _filterCategory(_listings);
  }

  List<ListingModel> _filterCategory(List<ListingModel> listings) {
    if (_homeSelectedCategoryId == null) return listings;
    final ids = <int>{_homeSelectedCategoryId!};
    for (final category in _categories) {
      if (category.id == _homeSelectedCategoryId) {
        ids.addAll(category.subcategories.map((subcategory) => subcategory.id));
      }
    }
    return listings.where((item) => ids.contains(item.categoryId)).toList();
  }

  String? _getCategoryIcon(int id) {
    if (_categories.isEmpty) return null;
    try {
      final cat = _categories.firstWhere((c) => c.id == id);
      return (cat.icon != null && cat.icon!.isNotEmpty) ? cat.icon : null;
    } catch (_) {
      return null;
    }
  }

  int? _getCatId(String slug) {
    if (_categories.isEmpty) return null;
    try {
      return _categories.firstWhere((c) => c.slug == slug).id;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiService();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF03172D),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    _loadFeedData();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentCity != widget.currentCity ||
        _loadedLatitude != globalLatitude ||
        _loadedLongitude != globalLongitude) {
      _loadFeedData();
    }
  }

  List<CategoryModel> _categories = [];

  Future<void> _loadFeedData() async {
    final request = ++_feedRequest;
    final locationChanged =
        _loadedCity != widget.currentCity ||
        _loadedLatitude != globalLatitude ||
        _loadedLongitude != globalLongitude;
    _loadedCity = widget.currentCity;
    _loadedLatitude = globalLatitude;
    _loadedLongitude = globalLongitude;
    setState(() {
      _isLoading = false;
      _recommendedLoading = true;
      _nearbyLoading = true;
      if (locationChanged) _nearbyListings = [];
      _feedFailures.clear();
      _feedError = null;
    });

    Future<void> load<T>(
      String section,
      Future<T> future,
      void Function(T) apply,
    ) async {
      try {
        final result = await future;
        if (!mounted || request != _feedRequest) return;
        setState(() => apply(result));
      } catch (_) {
        if (!mounted || request != _feedRequest) return;
        setState(() {
          _feedFailures[section] = section;
          _feedError =
              'Could not refresh ${_feedFailures.keys.join(' and ')}. '
              'Loaded items are still available. Please retry.';
        });
      } finally {
        if (mounted && request == _feedRequest) {
          setState(() {
            if (section == 'recommended') _recommendedLoading = false;
            if (section == 'nearby') _nearbyLoading = false;
          });
        }
      }
    }

    await Future.wait<void>([
      load<List<ListingModel>>(
        'recommended',
        _api.fetchListings(
          feed: 'recommended',
          city: widget.currentCity,
          throwOnError: true,
        ),
        (items) => _listings = items,
      ),
      load<List<CategoryModel>>(
        'categories',
        _api.fetchCategories(),
        (categories) => _categories = categories,
      ),
      load<List<ListingModel>>(
        'nearby',
        _fetchNearby(1),
        (items) => _nearbyListings = items,
      ),
    ]);
  }

  MarketplaceLocation get _feedLocation {
    final city = MarketplaceLocation.forCity(widget.currentCity);
    return MarketplaceLocation(
      widget.currentCity,
      latitude: globalLatitude ?? city.latitude,
      longitude: globalLongitude ?? city.longitude,
    );
  }

  Future<List<ListingModel>> _fetchNearby(int page) {
    final location = _feedLocation;
    return _api.fetchListings(
      feed: 'nearby',
      city: location.hasCoordinates ? null : widget.currentCity,
      latitude: location.latitude,
      longitude: location.longitude,
      radius: 50,
      page: page,
      throwOnError: true,
    );
  }

  Widget _feedSection(
    String title,
    String subtitle,
    List<ListingModel> listings,
    String emptyMessage,
    String feed,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF071A2F),
                  ),
                ),
              ),
              TextButton(
                key: ValueKey('view-all-$feed'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MarketplaceFeedScreen(
                      feed: feed,
                      location: _feedLocation,
                      api: _api,
                      categoryId: _homeSelectedCategoryId,
                      initialListings: _homeSelectedCategoryId == null
                          ? (feed == 'nearby' ? _nearbyListings : _listings)
                          : const [],
                    ),
                  ),
                ),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFF6B7785),
            ),
          ),
          const SizedBox(height: 12),
          if (listings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: (feed == 'nearby' ? _nearbyLoading : _recommendedLoading)
                  ? Center(
                      child: CircularProgressIndicator(
                        key: ValueKey('home-$feed-loading'),
                        color: AppColors.primary,
                      ),
                    )
                  : Text(
                      _feedFailures.containsKey(feed)
                          ? 'Unable to load this section. Tap Retry above.'
                          : emptyMessage,
                    ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 3 : 2;
                final width =
                    (constraints.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final listing in listings)
                      SizedBox(
                        width: width,
                        height: width / 0.70,
                        child: ListingCard(listing: listing),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF03172D),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: SafeArea(
          top: false,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : RefreshIndicator(
                  onRefresh: _loadFeedData,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    key: const Key('home-feed-scroll'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TOP DEEP NAVY HEADER: LOGO & LOCATION ON LEFT, SEARCH & PROFILE ON RIGHT
                        Container(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            MediaQuery.of(context).padding.top + 8,
                            16,
                            12,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFF03172D),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // LEFT SIDE: App Logo + Location status right after
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/logo_mobile.png',
                                    height: 32,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      'assets/images/logo.png',
                                      height: 32,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Location status placed on the left side after app logo
                                  InkWell(
                                    onTap: widget.onCitySelectTap,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.18),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.location_on_rounded,
                                            size: 14,
                                            color: Color(0xFF087CF5),
                                          ),
                                          const SizedBox(width: 4),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 85,
                                            ),
                                            child: Text(
                                              widget.currentCity,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 16,
                                            color: Colors.white70,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // RIGHT SIDE: Search button on the side of profile
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Search Button only (redirects to search page, follows brand theme)
                                  InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SearchExploreScreen(
                                            currentCity: widget.currentCity,
                                          ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF087CF5,
                                        ).withOpacity(0.18),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(
                                            0xFF087CF5,
                                          ).withOpacity(0.4),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.search_rounded,
                                          color: Color(0xFF087CF5),
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Profile Avatar
                                  InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const WalletScreen(),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Builder(
                                      builder: (context) {
                                        return Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF087CF5),
                                            border: Border.all(
                                              color: const Color(0xFF087CF5),
                                              width: 1.8,
                                            ),
                                          ),
                                          child: Center(
                                            child: const Tooltip(
                                              message: 'Wallet',
                                              child: Icon(
                                                Icons
                                                    .account_balance_wallet_outlined,
                                                color: Colors.white,
                                                size: 22,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // SUBTLE SOFT BLUE GRADIENT SHADE: From Shop Categories slightly getting white to bottom till above Recommended for you
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(
                                  0xFFE8F2FE,
                                ), // Very subtle soft ice-blue tint
                                Color(0xFFF3F8FF), // Fading soft mist blue
                                Color(
                                  0xFFF7F9FC,
                                ), // Smoothly blends into white right above Recommended for you
                              ],
                              stops: [0.0, 0.5, 1.0],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // SHOP CATEGORIES SECTION
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  18,
                                  16,
                                  8,
                                ),
                                child: Text(
                                  'Shop Categories',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF071A2F),
                                  ),
                                ),
                              ),

                              // 5 Category Carousel (Cars, Bikes, Mobiles, Electronics, Others)
                              SizedBox(
                                height: 96,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  children: [
                                    _buildCategoryItem(
                                      'Cars',
                                      _getCatId('cars'),
                                      imageAsset: 'assets/images/cat_cars.png',
                                    ),
                                    _buildCategoryItem(
                                      'Bikes',
                                      _getCatId('bikes-scooters'),
                                      imageAsset: 'assets/images/cat_bikes.png',
                                    ),
                                    _buildCategoryItem(
                                      'Mobiles',
                                      _getCatId('mobiles-tablets'),
                                      imageAsset:
                                          'assets/images/cat_mobiles.png',
                                    ),
                                    _buildCategoryItem(
                                      'Electronics',
                                      _getCatId('electronics'),
                                      imageAsset:
                                          'assets/images/cat_electronics.png',
                                    ),
                                    _buildCategoryItem(
                                      'Others',
                                      null,
                                      icon: Icons.more_horiz_rounded,
                                      accentColor: const Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                              // AdMob Promotional Banner
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  6,
                                  16,
                                  6,
                                ),
                                child: const AdMobBannerWidget(
                                  adSize: AdSize.largeBanner,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_feedError != null)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Text(_feedError!),
                                TextButton(
                                  onPressed: _loadFeedData,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        if (_homeSelectedCategoryId != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Showing ${_homeSelectedCategoryName ?? 'selected category'}',
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => setState(() {
                                    _homeSelectedCategoryId = null;
                                    _homeSelectedCategoryName = null;
                                  }),
                                  child: const Text('Clear filter'),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          key: _recommendedKey,
                          child: _feedSection(
                            'Recommended For You',
                            'Featured and recent marketplace items',
                            homePreviewItems(_displayedListings),
                            _displayedListings.isNotEmpty
                                ? 'Tap View all to see the available item.'
                                : 'No recommendations available in this category yet.',
                            'recommended',
                          ),
                        ),
                        Container(
                          key: _nearbyKey,
                          child: _feedSection(
                            'Nearby Items',
                            _feedLocation.hasCoordinates
                                ? 'Within 50 km of ${widget.currentCity}'
                                : 'Items in ${widget.currentCity} · select GPS for a 50 km radius',
                            homePreviewItems(_filterCategory(_nearbyListings)),
                            _filterCategory(_nearbyListings).isNotEmpty
                                ? 'Tap View all to see the available item.'
                                : 'No nearby items found. Try another location or category.',
                            'nearby',
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildFilterPill(int? catId, String label) {
    final isSelected = _homeSelectedCategoryId == catId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _homeSelectedCategoryId = catId;
            _homeSelectedCategoryName = catId == null ? null : label;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF087CF5) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF087CF5)
                  : const Color(0xFFD6DFE8),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: const Color(0xFF087CF5).withAlpha(40),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF071A2F),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(
    String label,
    int? categoryId, {
    String? imageAsset,
    String? imageUrl,
    IconData? icon,
    Color accentColor = const Color(0xFF087CF5),
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchExploreScreen(
                currentCity: widget.currentCity,
                initialCategoryId: categoryId,
                initialCategoryName: label,
              ),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5EAF0), width: 1),
              ),
              child: ClipOval(
                child:
                    imageUrl != null &&
                        (imageUrl.startsWith('http') ||
                            imageUrl.startsWith('/'))
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.network(
                          imageUrl.startsWith('/')
                              ? ApiConfig.resolveMediaUrl(imageUrl)
                              : imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            icon ?? Icons.category_rounded,
                            color: accentColor,
                            size: 28,
                          ),
                        ),
                      )
                    : imageAsset != null
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(imageAsset, fit: BoxFit.contain),
                      )
                    : Center(
                        child: Icon(
                          icon ?? Icons.category_rounded,
                          color: accentColor,
                          size: 28,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF071A2F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularCategory(
    String imageAsset,
    String label,
    int? categoryId,
  ) {
    final isSelected = _homeSelectedCategoryId == categoryId;
    return Expanded(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchExploreScreen(
                currentCity: widget.currentCity,
                initialCategoryId: categoryId,
                initialCategoryName: label,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(32),
        child: Column(
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF087CF5).withValues(alpha: 0.12)
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF087CF5)
                      : const Color(0xFFE2E8F0),
                  width: isSelected ? 2 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? const Color(0xFF087CF5).withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Image.asset(
                  imageAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.category_rounded,
                    color: Color(0xFF087CF5),
                    size: 26,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSelected
                    ? const Color(0xFF087CF5)
                    : const Color(0xFF071A2F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();

    // Lock system bars immediately to deep navy
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF03172D),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    // Animate within the available layout rather than scaling past its bounds.
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnim = Tween<double>(
      begin: 0.35 / 1.18,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutQuart));

    _opacityAnim = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _animCtrl.forward();

    // Check auth token, then route to Welcome or Home
    Future.delayed(const Duration(milliseconds: 2100), () async {
      if (!mounted) return;
      await AuthService().init();
      final isLoggedIn = AuthService().isAuthenticated;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => isLoggedIn
              ? ((AuthService().currentUser?.phone ?? '').isEmpty
                    ? const SignUpScreen(completeContact: true)
                    : const MainNavigationScreen(initialCity: 'Mumbai'))
              : const WelcomeScreen(),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF03172D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Preserve the logo's aspect ratio even on short landscape screens.
              const logoAspectRatio = 475 / 180;
              final maxWidth = (constraints.maxWidth * 0.85).clamp(0.0, 330.4);
              final logoWidth = maxWidth.clamp(
                0.0,
                constraints.maxHeight * logoAspectRatio,
              );
              return Center(
                child: AnimatedBuilder(
                  animation: _animCtrl,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _opacityAnim.value,
                      child: SizedBox(
                        key: const Key('splash-logo'),
                        width: logoWidth * _scaleAnim.value,
                        height: logoWidth / logoAspectRatio * _scaleAnim.value,
                        child: Image.asset(
                          'assets/images/logo_tight.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/images/logo_mobile.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ActiveUserManager removed - now using real AuthService accounts

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    AuthService().location.addListener(_locationChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  void _locationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthService().location.removeListener(_locationChanged);
    super.dispose();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out of OJIO?'),
        content: const Text(
          'You will need to log back in to manage your listings and chats.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE94B5F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService().logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && AuthService().isAuthenticated) {
      unawaited(ApiService().fetchUserProfile());
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final name = user?.name ?? 'OJIO User';
    final email = user?.email ?? '';
    final phone = user?.phone ?? 'Not set';
    final city = AuthService().location.value?.city ?? user?.city ?? 'Not set';
    final initials = name.isNotEmpty
        ? name
              .trim()
              .split(' ')
              .map((w) => w.isNotEmpty ? w[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : 'G';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(
                            24,
                            (MediaQuery.paddingOf(context).top + 48)
                                .clamp(70.0, double.infinity)
                                .toDouble(),
                            24,
                            32,
                          ),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF03172D), Color(0xFF07294D)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Avatar with initials
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withAlpha(80),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 28,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                name,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white60,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                '$phone  @  $city',
                                style: GoogleFonts.outfit(
                                  color: Colors.white38,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(20),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.verified_rounded,
                                      color: Color(0xFF087CF5),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      AuthService().isAuthenticated
                                          ? 'OJIO Member'
                                          : 'Sign in to OJIO',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: MediaQuery.paddingOf(context).top + 12,
                          right: 16,
                          child: PremiumBadge(
                            key: const ValueKey('profile-premium-badge'),
                            premium: user?.isPremium ?? false,
                            diamond: user?.hasDiamondBadge ?? false,
                            until: user?.premiumUntil,
                            diamondUntil: user?.diamondBadgeUntil,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Menu items
                    Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          _menuItem(
                            Icons.person_outline_rounded,
                            'Edit Profile',
                            'Update your info',
                            onTap: () async {
                              if (!AuthService().isAuthenticated) {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(
                                      returnToPrevious: true,
                                    ),
                                  ),
                                );
                                if (!mounted ||
                                    !AuthService().isAuthenticated) {
                                  return;
                                }
                              }
                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EditProfileScreen(),
                                ),
                              );
                              if (updated == true) setState(() {});
                            },
                          ),
                          const Divider(height: 1, indent: 56),
                          _menuItem(
                            Icons.workspace_premium_rounded,
                            'Get Premium',
                            'Boost your ads & unlock limits',
                            onLongPress: kDebugMode
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const PremiumPreviewScreen(),
                                      ),
                                    );
                                  }
                                : null,
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => PaywallModal(
                                  onPaymentSuccess: () {
                                    setState(() {});
                                  },
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1, indent: 56),
                          _menuItem(
                            Icons.location_on_outlined,
                            'City & Location',
                            city,
                            onTap: () async {
                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CityLocationScreen(),
                                ),
                              );
                              if (updated == true) setState(() {});
                            },
                          ),
                          const Divider(height: 1, indent: 56),
                          _menuItem(
                            Icons.notifications_none_rounded,
                            'Notifications',
                            'Active',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const NotificationsSettingsScreen(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1, indent: 56),
                          _menuItem(
                            Icons.help_outline_rounded,
                            'Help & Support',
                            '24x7',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HelpSupportScreen(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1, indent: 56),
                          _menuItem(
                            Icons.info_outline_rounded,
                            'About OJIO',
                            'v1.0.0',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AboutOjioScreen(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1, indent: 56),
                          ListTile(
                            leading: const Icon(
                              Icons.logout_rounded,
                              color: Color(0xFFE94B5F),
                              size: 22,
                            ),
                            title: Text(
                              AuthService().isAuthenticated
                                  ? 'Log Out'
                                  : 'Log In',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: const Color(0xFFE94B5F),
                              ),
                            ),
                            onTap: AuthService().isAuthenticated
                                ? _logout
                                : () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const LoginScreen(
                                          returnToPrevious: true,
                                        ),
                                      ),
                                    );
                                    if (mounted) setState(() {});
                                  },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.paddingOf(context).top,
              child: const ColoredBox(
                key: ValueKey('profile-status-bar-background'),
                color: Color(0xFF03172D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(
    IconData icon,
    String title,
    String trailing, {
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return ListTile(
      onLongPress: onLongPress,
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        title,
        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.38,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                trailing,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
      onTap: onTap,
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _slides = [
    {
      'title': 'Find Verified Deals Nearby',
      'subtitle':
          'Discover cars, bikes, smartphones, and gadgets within 5km of your doorstep using smart GPS radius.',
      'icon': 'directions_car_rounded',
      'badge': 'GPS LOCALITY',
    },
    {
      'title': 'Sell Free with Zero Commission',
      'subtitle':
          'Post your first 2 classified ads completely FREE! Quick photos, accurate specifications, and instant listing.',
      'icon': 'stars_rounded',
      'badge': '2 FREE ADS',
    },
    {
      'title': 'Direct Chat & 1-Tap Call',
      'subtitle':
          'Negotiate directly with buyers & sellers. Instant in-app messaging, verified user badges, and privacy controls.',
      'icon': 'chat_bubble_rounded',
      'badge': 'SAFE & SECURE',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Brand & Skip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(15),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'OJIO',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: AppColors.darkBrand,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _navigateToLocation,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.outfit(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Illustration badge
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withAlpha(18),
                            border: Border.all(
                              color: AppColors.primary.withAlpha(40),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              _getIcon(slide['icon']!),
                              size: 80,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.darkBrand,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            slide['badge']!,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          slide['title']!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMain,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide['subtitle']!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Bottom Indicator & CTA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dot Indicators
                  Row(
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  // Next / Get Started Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () {
                      if (_currentPage < _slides.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _navigateToLocation();
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == _slides.length - 1
                              ? 'Get Started'
                              : 'Next',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String name) {
    switch (name) {
      case 'directions_car_rounded':
        return Icons.directions_car_rounded;
      case 'stars_rounded':
        return Icons.stars_rounded;
      default:
        return Icons.chat_bubble_rounded;
    }
  }

  void _navigateToLocation() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LocationSelectScreen()),
    );
  }
}
