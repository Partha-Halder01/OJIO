import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/feed_ad_placements.dart';
import '../core/marketplace_location.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/app_notice.dart';
import '../widgets/listing_card.dart';
import '../widgets/admob_banner_widget.dart';

class MarketplaceFeedScreen extends StatefulWidget {
  final String feed;
  final MarketplaceLocation location;
  final ApiService? api;
  final List<ListingModel> initialListings;
  final int? categoryId;

  const MarketplaceFeedScreen({
    super.key,
    required this.feed,
    required this.location,
    this.api,
    this.initialListings = const [],
    this.categoryId,
  });

  @override
  State<MarketplaceFeedScreen> createState() => _MarketplaceFeedScreenState();
}

class _MarketplaceFeedScreenState extends State<MarketplaceFeedScreen> {
  late final ApiService _api;
  late List<ListingModel> _items;
  int _page = 1;
  bool _loading = false;
  bool _hasMore = false;
  String? _error;
  final _adPlacements = FeedAdPlacements();
  bool get _nearby => widget.feed == 'nearby';

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiService();
    _items = List.of(widget.initialListings);
    _hasMore = _items.length == 20;
    if (_items.isEmpty) _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final page = refresh ? 1 : _page + 1;
    try {
      final results = await _api.fetchListings(
        feed: widget.feed,
        categoryId: widget.categoryId,
        city: _nearby && widget.location.hasCoordinates
            ? null
            : widget.location.city,
        latitude: _nearby ? widget.location.latitude : null,
        longitude: _nearby ? widget.location.longitude : null,
        radius: 50,
        page: page,
        throwOnError: true,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) _items.clear();
        final ids = _items.map((item) => item.id).toSet();
        _items.addAll(results.where((item) => ids.add(item.id)));
        _page = page;
        _hasMore = results.length == 20;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not load items. Please retry.');
      AppNotice.show(context, SnackBar(content: Text(_error!)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _listingGrid(int start, int end, int columns) {
    return SliverGrid(
      key: ValueKey('feed-grid-$start'),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.70,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => ListingCard(
          key: ValueKey('feed-listing-${_items[start + index].id}'),
          listing: _items[start + index],
        ),
        childCount: end - start,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.darkBrand,
        foregroundColor: Colors.white,
        title: Text(_nearby ? 'Nearby Items' : 'Recommended For You'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: CustomScrollView(
          key: ValueKey('all-${widget.feed}-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_nearby)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.location.hasCoordinates
                        ? 'Nearest first · within 50 km of ${widget.location.city}'
                        : 'Items in ${widget.location.city} · select GPS for distance ordering',
                  ),
                ),
              ),
            if (_loading && _items.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error ?? 'No items found.'),
                      if (_error != null)
                        TextButton(
                          onPressed: () => _load(refresh: true),
                          child: const Text('Retry'),
                        ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(14),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.crossAxisExtent >= 700 ? 3 : 2;
                    final boundaries = _adPlacements.boundaries(
                      itemCount: _items.length,
                      columns: columns,
                    );
                    final slivers = <Widget>[];
                    var start = 0;
                    for (final end in boundaries) {
                      slivers.add(_listingGrid(start, end, columns));
                      slivers.add(
                        SliverToBoxAdapter(
                          key: ValueKey('feed-ad-$end'),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: AdMobBannerWidget(
                              adSize: AdSize.largeBanner,
                            ),
                          ),
                        ),
                      );
                      start = end;
                    }
                    slivers.add(_listingGrid(start, _items.length, columns));
                    return SliverMainAxisGroup(slivers: slivers);
                  },
                ),
              ),
            if (_hasMore)
              SliverToBoxAdapter(
                child: Center(
                  child: TextButton(
                    onPressed: _loading ? null : () => _load(),
                    child: Text(_loading ? 'Loading…' : 'Load more items'),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
