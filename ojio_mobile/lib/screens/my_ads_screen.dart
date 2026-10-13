import '../widgets/app_notice.dart';
import '../widgets/app_image_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/my_ads_updates_service.dart';
import 'listing_detail_screen.dart';
import 'post_ad_screen.dart';

class MyAdsScreen extends StatefulWidget {
  final bool active;
  final ApiService? api;
  const MyAdsScreen({super.key, this.active = true, this.api});

  @override
  State<MyAdsScreen> createState() => _MyAdsScreenState();
}

class _MyAdsScreenState extends State<MyAdsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late final ApiService _apiService;

  List<ListingModel> _allAds = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _loadRevision = 0;

  @override
  void initState() {
    super.initState();
    _apiService = widget.api ?? ApiService();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);
    _loadListings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MyAdsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _loadListings();
  }

  Future<void> _loadListings() async {
    final revision = ++_loadRevision;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = AuthService().token;
      final snapshot = await _apiService.fetchMyAdsSnapshot();
      if (token != AuthService().token || revision != _loadRevision) return;
      final rows = (snapshot['data'] as List).cast<Map<String, dynamic>>();
      final items = rows.map(ListingModel.fromJson).toList();
      if (mounted) {
        setState(() {
          _allAds = items;
          _isLoading = false;
        });
        if (widget.active &&
            ModalRoute.of(context)?.isCurrent == true &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
          await MyAdsUpdatesService.instance.acknowledge([
            for (final row in rows)
              if ((int.tryParse('${row['admin_update_version']}') ?? 0) > 0)
                {
                  'id': row['id'],
                  'version': int.parse('${row['admin_update_version']}'),
                },
          ], token);
        }
      }
    } catch (e) {
      if (mounted && revision == _loadRevision) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.active &&
        ModalRoute.of(context)?.isCurrent == true) {
      _loadListings();
    }
  }

  Future<void> _markSold(ListingModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Mark as Sold?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to mark "${item.title}" as sold?',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A86B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Mark Sold',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.markListingAsSold(item.id);
        if (mounted) {
          AppNotice.show(
            context,
            const SnackBar(
              content: Text('Listing marked as sold successfully!'),
              backgroundColor: Color(0xFF00A86B),
            ),
          );
          _loadListings();
        }
      } catch (e) {
        if (mounted) {
          AppNotice.show(
            context,
            SnackBar(
              content: Text('Failed: '),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteAd(ListingModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Listing?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete "${item.title}"? This action cannot be undone.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteListing(item.id);
        if (mounted) {
          AppNotice.show(
            context,
            const SnackBar(content: Text('Listing deleted successfully.')),
          );
          _loadListings();
        }
      } catch (e) {
        if (mounted) {
          AppNotice.show(
            context,
            SnackBar(
              content: Text('Failed: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAds = _allAds.where((a) => a.status == 'active').toList();
    final soldAds = _allAds.where((a) => a.status == 'sold').toList();
    final rejectedAds = _allAds.where((a) => a.status == 'rejected').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF03172D),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF03172D),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: Text(
          'My Ads',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadListings,
          ),
        ],
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 10),
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          dividerColor: Colors.white12,
          labelStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          indicatorColor: const Color(0xFF087CF5),
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'All (${_allAds.length})'),
            Tab(text: 'Active (${activeAds.length})'),
            Tab(text: 'Sold (${soldAds.length})'),
            Tab(text: 'Rejected (${rejectedAds.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load listings',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadListings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Text(
                        'Try Again',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildListingList(_allAds, 'No listings yet'),
                _buildListingList(activeAds, 'No active ads'),
                _buildListingList(soldAds, 'No sold ads'),
                _buildListingList(rejectedAds, 'No rejected ads'),
              ],
            ),
    );
  }

  Widget _buildListingList(List<ListingModel> items, String emptyTitle) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF087CF5).withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.post_add_rounded,
                  size: 36,
                  color: const Color(0xFF087CF5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'List items you want to sell and they will appear here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              if (_tabController.index == 0 || _tabController.index == 1) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    final created = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PostAdScreen()),
                    );
                    if (created == true) _loadListings();
                  },
                  icon: const Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Post an Ad Now',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF087CF5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20b9',
      decimalDigits: 0,
    );

    return RefreshIndicator(
      onRefresh: _loadListings,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSold = item.status == 'sold';
          final isRejected = item.status == 'rejected';
          final imageUrl = ListingModel.sanitizeImageUrl(
            item.images.isNotEmpty ? item.images.first : item.primaryImageUrl,
            categorySlug: item.categorySlug,
            title: item.title,
          );

          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            shadowColor: Colors.black.withAlpha(6),
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ListingDetailScreen(listing: item),
                  ),
                );
                _loadListings();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: AppImageView(
                        url: imageUrl,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(12),
                        categorySlug: item.categorySlug,
                        title: item.title,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isRejected
                                      ? const Color(0xFFEF4444).withAlpha(25)
                                      : isSold
                                      ? const Color(0xFF64748B).withAlpha(20)
                                      : const Color(0xFF00A86B).withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isRejected
                                      ? 'REJECTED'
                                      : isSold
                                      ? 'SOLD'
                                      : 'ACTIVE',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isRejected
                                        ? const Color(0xFFEF4444)
                                        : isSold
                                        ? const Color(0xFF64748B)
                                        : const Color(0xFF00A86B),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    size: 20,
                                    color: AppColors.textSecondary,
                                  ),
                                  onSelected: (val) async {
                                    if (val == 'edit') {
                                      final updated = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PostAdScreen(editListing: item),
                                        ),
                                      );
                                      if (updated == true) _loadListings();
                                    }
                                    if (val == 'sold') _markSold(item);
                                    if (val == 'delete') _deleteAd(item);
                                  },
                                  itemBuilder: (ctx) => [
                                    if (!isSold) ...[
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                              color: Color(0xFF087CF5),
                                            ),
                                            SizedBox(width: 8),
                                            Text('Edit Listing'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'sold',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons
                                                  .check_circle_outline_rounded,
                                              size: 18,
                                              color: Color(0xFF00A86B),
                                            ),
                                            SizedBox(width: 8),
                                            Text('Mark as Sold'),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                            color: AppColors.error,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Delete Listing'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.textMain,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            currency.format(item.price),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: const Color(0xFF087CF5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item.city,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isRejected) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFCA5A5),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 16,
                                    color: Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.rejectionReason != null &&
                                              item.rejectionReason!.isNotEmpty
                                          ? 'Removed by Admin: ' +
                                                item.rejectionReason!
                                          : 'Removed by Admin: Incomplete or non-compliant ad. Please edit and resubmit.',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: const Color(0xFF991B1B),
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
