import 'dart:async';
import '../main.dart';
import '../widgets/app_image_view.dart';
import '../core/constants.dart' as marketplace_config;
import '../widgets/admob_banner_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/listing_card.dart';
import 'filter_bottom_sheet.dart';

class SearchExploreScreen extends StatefulWidget {
  final String currentCity;
  final int? initialCategoryId;
  final String? initialCategoryName;
  final ApiService? api;

  const SearchExploreScreen({
    super.key,
    required this.currentCity,
    this.initialCategoryId,
    this.initialCategoryName,
    this.api,
  });

  @override
  State<SearchExploreScreen> createState() => _SearchExploreScreenState();
}

class _SearchExploreScreenState extends State<SearchExploreScreen> {
  late final ApiService _api;
  final TextEditingController _searchCtrl = TextEditingController();
  List<ListingModel> _allResults = [];
  List<ListingModel> _filteredResults = [];
  bool _isLoading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  int _searchRequest = 0;
  String? _searchError;
  Timer? _suggestionTimer;
  int _suggestionRequest = 0;
  List<String> _suggestions = [];
  String _submittedQuery = '';
  double _radius = 50;
  double? _minPrice;
  double? _maxPrice;

  int? _selectedCategoryId;
  String? _selectedCategoryName;
  int? _selectedSubcategoryId;
  String? _selectedSubcategoryName;

  // Active filters
  RangeValues _priceRange = const RangeValues(0, 5000000);

  // Main Categories definition
  final List<Map<String, dynamic>> _categoryStyles = [
    {'slug': 'all', 'name': 'All', 'icon': Icons.all_inclusive_rounded},
    {'slug': 'cars', 'name': 'Cars', 'image': 'assets/images/cat_cars.png'},
    {
      'slug': 'commercial-vehicles',
      'name': 'Commercial',
      'icon': Icons.local_shipping_rounded,
      'color': Color(0xFFEAB308),
    },
    {
      'slug': 'bikes-scooters',
      'name': 'Bikes',
      'image': 'assets/images/cat_bikes.png',
    },
    {
      'slug': 'mobiles-tablets',
      'name': 'Mobiles',
      'image': 'assets/images/cat_mobiles.png',
    },
    {
      'slug': 'electronics',
      'name': 'Electronics',
      'image': 'assets/images/cat_electronics.png',
    },
    {
      'slug': 'real-estate',
      'name': 'Real Estate',
      'image': 'assets/images/real-estate.png',
      'color': Color(0xFFEAB308),
    },
    {
      'slug': 'jobs',
      'name': 'Jobs',
      'image': 'assets/images/jobs.png',
      'color': Color(0xFFEC4899),
    },
    {
      'slug': 'furniture',
      'name': 'Furniture',
      'image': 'assets/images/furniture.png',
      'color': Color(0xFF6366F1),
    },
    {
      'slug': 'fashion',
      'name': 'Fashion',
      'icon': Icons.checkroom_rounded,
      'color': Color(0xFF64748B),
    },
    {
      'slug': 'sports-fitness',
      'name': 'Sports & Fitness',
      'icon': Icons.sports_soccer_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'slug': 'home-appliances',
      'name': 'Home & Appl.',
      'icon': Icons.kitchen_rounded,
      'color': Color(0xFF0EA5E9),
    },
    {
      'slug': 'services',
      'name': 'Services',
      'icon': Icons.handyman_rounded,
      'color': Color(0xFFF97316),
    },
    {
      'slug': 'books-education',
      'name': 'Books',
      'icon': Icons.menu_book_rounded,
      'color': Color(0xFF8B5CF6),
    },
    {
      'slug': 'pets-animals',
      'name': 'Pets',
      'icon': Icons.pets_rounded,
      'color': Color(0xFFEC4899),
    },
    {
      'slug': 'agriculture',
      'name': 'Agriculture',
      'icon': Icons.agriculture_rounded,
      'color': Color(0xFF16A34A),
    },
    {
      'slug': 'gaming',
      'name': 'Gaming',
      'icon': Icons.sports_esports_rounded,
      'color': Color(0xFF7C3AED),
    },
  ];

  IconData _getCategoryIcon(String slug) {
    slug = slug.toLowerCase();
    if (slug.contains('car') && !slug.contains('game'))
      return Icons.directions_car_filled_rounded;
    if (slug.contains('commercial') ||
        slug.contains('truck') ||
        slug.contains('vehicle'))
      return Icons.local_shipping_rounded;
    if (slug.contains('bike') ||
        slug.contains('scooter') ||
        slug.contains('moped'))
      return Icons.two_wheeler_rounded;
    if (slug.contains('mobil') ||
        slug.contains('tablet') ||
        slug.contains('phone'))
      return Icons.smartphone_rounded;
    if (slug.contains('elect') && !slug.contains('vehicle'))
      return Icons.laptop_chromebook_rounded;
    if (slug.contains('estate') ||
        slug.contains('apartment') ||
        slug.contains('property'))
      return Icons.apartment_rounded;
    if (slug.contains('job') ||
        slug.contains('work') ||
        slug.contains('career'))
      return Icons.work_rounded;
    if (slug.contains('furnit') ||
        slug.contains('sofa') ||
        slug.contains('bed'))
      return Icons.chair_rounded;
    if (slug.contains('fashion') ||
        slug.contains('cloth') ||
        slug.contains('wear'))
      return Icons.checkroom_rounded;
    if (slug.contains('sport') ||
        slug.contains('fitness') ||
        slug.contains('gym'))
      return Icons.sports_soccer_rounded;
    if (slug.contains('home') ||
        slug.contains('appliance') ||
        slug.contains('kitchen'))
      return Icons.kitchen_rounded;
    if (slug.contains('service') ||
        slug.contains('repair') ||
        slug.contains('plumb'))
      return Icons.handyman_rounded;
    if (slug.contains('book') ||
        slug.contains('education') ||
        slug.contains('study'))
      return Icons.menu_book_rounded;
    if (slug.contains('pet') ||
        slug.contains('animal') ||
        slug.contains('dog') ||
        slug.contains('cat'))
      return Icons.pets_rounded;
    if (slug.contains('agri') || slug.contains('farm') || slug.contains('crop'))
      return Icons.agriculture_rounded;
    if (slug.contains('gaming') ||
        slug.contains('game') ||
        slug.contains('console') ||
        slug.contains('xbox') ||
        slug.contains('ps5'))
      return Icons.sports_esports_rounded;
    return Icons.grid_view_rounded;
  }

  List<CategoryModel> _apiCategories = [];

  List<Map<String, dynamic>> get _categories => [
    {'slug': 'all', 'name': 'All', 'icon': Icons.all_inclusive_rounded},
    for (final category in _apiCategories)
      if (category.slug.toLowerCase() != 'others' &&
          category.name.trim().toLowerCase() != 'others')
        {
          ..._categoryStyles.firstWhere(
            (style) => style['slug'] == category.slug,
            orElse: () => {'icon': _getCategoryIcon(category.slug)},
          ),
          'id': category.id,
          'slug': category.slug,
          'name': category.name,
          'iconUrl': category.icon?.startsWith('/') == true
              ? '${marketplace_config.AppConstants.storageBaseUrl}${category.icon}'
              : category.icon,
        },
  ];

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiService();
    _selectedCategoryId = widget.initialCategoryId;
    _selectedCategoryName = widget.initialCategoryId == null
        ? null
        : widget.initialCategoryName;
    _fetchCategoriesAndSearch();
  }

  Future<void> _fetchCategoriesAndSearch() async {
    setState(() => _isLoading = true);
    final search = _performSearch();
    try {
      final categories = await _api.fetchCategories();
      if (!mounted) return;
      setState(() {
        _apiCategories = categories;
        if (_selectedCategoryId != null) {
          final matches = categories.where(
            (category) => category.id == _selectedCategoryId,
          );
          if (matches.isNotEmpty) _selectedCategoryName = matches.first.name;
        }
      });
    } catch (_) {}
    await search;
  }

  int? _getCatIdFromSlug(String slug) {
    if (slug == 'all') return null;
    try {
      return _apiCategories.firstWhere((c) => c.slug == slug).id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _performSearch() async {
    if (!mounted) return;
    _suggestionTimer?.cancel();
    _suggestionRequest++;
    _submittedQuery = _searchCtrl.text.trim();
    FocusManager.instance.primaryFocus?.unfocus();
    final request = ++_searchRequest;
    setState(() {
      _isLoading = true;
      _loadingMore = false;
      _searchError = null;
      _page = 1;
      _suggestions = [];
    });
    try {
      final results = await _searchPage(1);
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _allResults = results;
        _hasMore = results.length == 20;
        _applyLocalFilters();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted && request == _searchRequest)
        setState(() {
          _isLoading = false;
          _searchError = 'Unable to load results. Please retry.';
        });
    }
  }

  Future<List<ListingModel>> _searchPage(int page) => _api.fetchListings(
    categoryId: _selectedSubcategoryId ?? _selectedCategoryId,
    query: _submittedQuery,
    city: globalLatitude == null ? widget.currentCity : null,
    latitude: globalLatitude,
    longitude: globalLongitude,
    radius: _radius,
    minPrice: _minPrice,
    maxPrice: _maxPrice,
    page: page,
    throwOnError: true,
  );

  void _suggest(String value) {
    _suggestionTimer?.cancel();
    final request = ++_suggestionRequest;
    setState(() => _suggestions = []);
    final query = value.trim();
    if (query.length < 2) return;
    _suggestionTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final suggestions = await _api.fetchSearchSuggestions(
          query,
          categoryId: _selectedSubcategoryId ?? _selectedCategoryId,
          city: globalLatitude == null ? widget.currentCity : null,
          latitude: globalLatitude,
          longitude: globalLongitude,
          radius: _radius,
        );
        if (mounted && request == _suggestionRequest) {
          setState(() => _suggestions = suggestions);
        }
      } catch (_) {
        // Search submission remains usable if suggestions are offline.
      }
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final request = _searchRequest;
    setState(() {
      _loadingMore = true;
      _searchError = null;
    });
    try {
      final results = await _searchPage(_page + 1);
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _page++;
        final ids = _allResults.map((item) => item.id).toSet();
        _allResults.addAll(results.where((item) => ids.add(item.id)));
        _hasMore = results.length == 20;
        _applyLocalFilters();
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && request == _searchRequest)
        setState(() {
          _loadingMore = false;
          _searchError = 'Unable to load more results. Please retry.';
        });
    }
  }

  void _applyLocalFilters() {
    _filteredResults = _allResults.where((item) {
      if ((_minPrice != null && item.price < _minPrice!) ||
          (_maxPrice != null && item.price > _maxPrice!)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _selectCategory(String slug, String name) {
    setState(() {
      _selectedCategoryName = name == 'All' ? null : name;
      _selectedSubcategoryId = null;
      _selectedSubcategoryName = null;
      if (slug == 'all') {
        _selectedCategoryId = null;
      } else {
        _selectedCategoryId = _getCatIdFromSlug(slug);
      }
    });
    _performSearch();
  }

  void _selectSubcategory(int id, String name) {
    setState(() {
      if (_selectedSubcategoryId == id) {
        _selectedSubcategoryId = null;
        _selectedSubcategoryName = null;
      } else {
        _selectedSubcategoryId = id;
        _selectedSubcategoryName = name;
      }
    });
    _performSearch();
  }

  void _openFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterBottomSheet(
        initialPriceRange: _priceRange,
        initialRadius: _radius,
        hasCoordinates: globalLatitude != null && globalLongitude != null,
        onApply: (filters) {
          setState(() {
            _priceRange = RangeValues(
              (filters['min_price'] as num).toDouble(),
              (filters['max_price'] as num).toDouble(),
            );
            _minPrice = _priceRange.start;
            _maxPrice = _priceRange.end == 5000000 ? null : _priceRange.end;
            _radius = (filters['radius'] as num).toDouble();
          });
          _performSearch();
        },
      ),
    );
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    _suggestionRequest++;
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryLabelHeight =
        MediaQuery.textScalerOf(context).scale(12) * 2.6;
    List<CategoryModel>? activeSubcategories;
    if (_selectedCategoryId != null) {
      try {
        final cat = _apiCategories.firstWhere(
          (c) => c.id == _selectedCategoryId,
        );
        if (cat.subcategories.isNotEmpty) {
          activeSubcategories = cat.subcategories;
        }
      } catch (_) {}
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFF03172D),
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        backgroundColor: const Color(0xFF03172D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _suggest,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _performSearch(),
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF071A2F),
            ),
            decoration: InputDecoration(
              hintText: _selectedCategoryName != null
                  ? 'Search in $_selectedCategoryName...'
                  : 'Search cars, bikes, mobiles, appliances...',
              hintStyle: GoogleFonts.outfit(
                color: const Color(0xFF94A3B8),
                fontSize: 12,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              prefixIcon: IconButton(
                tooltip: 'Search',
                onPressed: _performSearch,
                icon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF64748B),
                  size: 18,
                ),
              ),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        _performSearch();
                      },
                    )
                  : null,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_searchError != null)
                MaterialBanner(
                  content: Text(_searchError!),
                  actions: [
                    TextButton(
                      onPressed: _performSearch,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              // 1. Horizontal Category Circular Navigation (Styled like Home Page)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: SizedBox(
                  height: 60 + categoryLabelHeight,
                  child: ListView.builder(
                    itemExtent: 96,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final catSlug = cat['slug'] as String;
                      final catName = cat['name'] as String;

                      final isSelected =
                          catName == (_selectedCategoryName ?? 'All');

                      final String? imageAsset = cat['image'];
                      final String? iconUrl = cat['iconUrl'];
                      final IconData icon =
                          cat['icon'] ?? Icons.category_rounded;
                      final Color accentColor =
                          cat['color'] ?? const Color(0xFF087CF5);

                      return Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: InkWell(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () => _selectCategory(catSlug, catName),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF087CF5)
                                        : const Color(0xFFE2E8F0),
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF087CF5,
                                            ).withAlpha(50),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: ClipOval(
                                  child:
                                      iconUrl != null &&
                                          iconUrl.startsWith('http')
                                      ? Padding(
                                          padding: const EdgeInsets.all(7),
                                          child: AppImageView(
                                            url: iconUrl,
                                            fit: BoxFit.contain,
                                          ),
                                        )
                                      : imageAsset != null
                                      ? Padding(
                                          padding: const EdgeInsets.all(7),
                                          child: Image.asset(
                                            imageAsset,
                                            fit: BoxFit.contain,
                                          ),
                                        )
                                      : Center(
                                          child: Icon(
                                            icon,
                                            color: isSelected
                                                ? const Color(0xFF087CF5)
                                                : accentColor,
                                            size: 24,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                cat['name'] as String,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? const Color(0xFF087CF5)
                                      : const Color(0xFF071A2F),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 2. Famous Companies / Subcategories Grid
              if (activeSubcategories != null && activeSubcategories.isNotEmpty)
                Container(
                  color: const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: SizedBox(
                    height: 70 + categoryLabelHeight,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: activeSubcategories.length,
                      itemExtent: 96,
                      itemBuilder: (context, index) {
                        final subcat = activeSubcategories![index];
                        final isSelected = _selectedSubcategoryId == subcat.id;
                        final icon = _getCategoryIcon(subcat.slug);
                        return Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: GestureDetector(
                            onTap: () =>
                                _selectSubcategory(subcat.id, subcat.name),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 62,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF087CF5)
                                          : const Color(0xFFE2E8F0),
                                      width: isSelected ? 2.5 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF087CF5,
                                              ).withAlpha(50),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      icon,
                                      color: isSelected
                                          ? const Color(0xFF087CF5)
                                          : const Color(0xFF64748B),
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    subcat.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? const Color(0xFF087CF5)
                                          : const Color(0xFF071A2F),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              // 3. Results Header with Count and Filter Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${_filteredResults.length} Items Found',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF071A2F),
                            ),
                          ),
                          if (_selectedCategoryName != null) ...[
                            Container(
                              constraints: const BoxConstraints(maxWidth: 140),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF087CF5).withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _selectedCategoryName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF087CF5),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openFilterDialog,
                      icon: const Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: Color(0xFF087CF5),
                      ),
                      label: Text(
                        'Filters',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: const Color(0xFF087CF5),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        side: const BorderSide(color: Color(0xFF087CF5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // AdMob Sponsored Banner
              const AdMobBannerWidget(showLabel: false),

              // 4. Listing Grid Results
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF087CF5),
                        ),
                      )
                    : _filteredResults.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.search_off_rounded,
                                size: 56,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No items found in ${_selectedSubcategoryName ?? _selectedCategoryName ?? "All"}',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF071A2F),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Try another category, location or search term.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedCategoryId = null;
                                    _selectedCategoryName = null;
                                    _selectedSubcategoryId = null;
                                    _selectedSubcategoryName = null;
                                    _searchCtrl.clear();
                                  });
                                  _performSearch();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF087CF5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('View All Categories'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _performSearch,
                        color: const Color(0xFF087CF5),
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.70,
                              ),
                          itemCount: _filteredResults.length,
                          itemBuilder: (context, index) {
                            return ListingCard(
                              listing: _filteredResults[index],
                            );
                          },
                        ),
                      ),
              ),
              if (_hasMore && !_isLoading)
                SafeArea(
                  top: false,
                  child: TextButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: Text(
                      _loadingMore ? 'Loading…' : 'Load more results',
                    ),
                  ),
                ),
            ],
          ),
          if (_suggestions.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                elevation: 4,
                color: AppColors.card,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        (MediaQuery.sizeOf(context).height -
                                MediaQuery.viewInsetsOf(context).bottom -
                                MediaQuery.paddingOf(context).top -
                                kToolbarHeight)
                            .clamp(0.0, 190.0),
                  ),
                  child: ListView(
                    key: const ValueKey('search-suggestions'),
                    shrinkWrap: true,
                    children: [
                      for (final suggestion in _suggestions)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.search, size: 18),
                          title: Text(
                            suggestion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            _searchCtrl.text = suggestion;
                            _performSearch();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
