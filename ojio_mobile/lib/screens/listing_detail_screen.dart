import '../widgets/premium_badge.dart';
import '../widgets/app_notice.dart';
import '../widgets/app_image_view.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_screen.dart';
import 'post_ad_screen.dart';
import 'login_screen.dart';
import 'listing_photo_viewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';

class ListingDetailScreen extends StatelessWidget {
  final ListingModel listing;

  const ListingDetailScreen({super.key, required this.listing});

  @override
  Widget build(BuildContext context) {
    final photos = listing.images.isNotEmpty
        ? listing.images
        : [
            if (listing.primaryImageUrl?.isNotEmpty ?? false)
              listing.primaryImageUrl!,
          ];
    Widget photo(int index) => GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ListingPhotoViewer(images: photos, initialIndex: index),
        ),
      ),
      child: AppImageView(
        url: photos[index],
        height: 280,
        width: double.infinity,
        fit: BoxFit.cover,
        categorySlug: listing.categorySlug,
        title: listing.title,
      ),
    );
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          listing.title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: AppColors.textMain,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.card,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.textMain,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (AuthService().currentUser != null &&
              (AuthService().currentUser!.id == listing.userId) &&
              listing.status != 'sold')
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              tooltip: 'Edit Ad',
              onPressed: () async {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostAdScreen(editListing: listing),
                  ),
                );
                if (updated == true) {
                  Navigator.pop(context, true);
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.textMain),
            onPressed: () {
              AppNotice.show(
                context,
                const SnackBar(
                  content: Text('Sharing ad link with friends...'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.favorite_border_rounded,
              color: AppColors.textMain,
            ),
            onPressed: () {
              AppNotice.show(
                context,
                const SnackBar(content: Text('Listing saved to favorites!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Photo
            Stack(
              children: [
                if (photos.length > 1)
                  CarouselSlider(
                    options: CarouselOptions(
                      height: 280,
                      viewportFraction: 1.0,
                      enableInfiniteScroll: false,
                    ),
                    items: List.generate(photos.length, photo),
                  )
                else if (photos.isNotEmpty)
                  photo(0)
                else
                  AppImageView(
                    url: listing.primaryImageUrl,
                    height: 280,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    categorySlug: listing.categorySlug,
                    title: listing.title,
                  ),
                if (photos.isNotEmpty)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${photos.length} photo${photos.length == 1 ? '' : 's'} · tap to view',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (listing.isFeatured)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(40),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        'FEATURED AD',
                        style: GoogleFonts.outfit(
                          color: AppColors.darkBrand,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Main Product Card
            Container(
              color: AppColors.card,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currency.format(listing.price),
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    listing.title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${listing.locality != null ? "${listing.locality}, " : ""}${listing.city}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM yyyy').format(listing.createdAt),
                        style: GoogleFonts.outfit(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _contactActions(context),
            const SizedBox(height: 12),

            // Specifications (Vehicles / Mobiles)
            if (listing.attributes.isNotEmpty) ...[
              Container(
                width: double.infinity,
                color: AppColors.card,
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    title: Text(
                      'Specifications & Highlights',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: 20,
                    ),
                    children: [
                      Column(
                        children: listing.attributes.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    entry.key[0].toUpperCase() +
                                        entry.key
                                            .substring(1)
                                            .toLowerCase(), // Capitalize first letter
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    entry.value.toString(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMain,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Description
            Container(
              width: double.infinity,
              color: AppColors.card,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seller Description',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    listing.description ??
                        'No additional description provided.',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: const Color(0xFF475569),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // In-Ad Promotional Banner Slot (Scope Quotation deliverable)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.navyGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.darkBrand.withAlpha(50),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OJIO Safe Trade Protection',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Never send advance payments. Inspect in person.',
                          style: GoogleFonts.outfit(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Seller Card
            Container(
              color: AppColors.card,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withAlpha(25),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              listing.sellerName ?? 'OJIO Seller',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppColors.textMain,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            PremiumBadge(
                              premium: listing.sellerIsPremium,
                              diamond: listing.sellerHasDiamondBadge,
                              until: listing.sellerPremiumUntil,
                              diamondUntil: listing.sellerDiamondBadgeUntil,
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Verified Member since 2026',
                          style: GoogleFonts.outfit(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat(BuildContext context) async {
    if (!AuthService().isAuthenticated) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(returnToPrevious: true),
        ),
      );
      if (!context.mounted || !AuthService().isAuthenticated) return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          threadId: 0,
          listingId: listing.id,
          otherUserName: listing.sellerName ?? 'OJIO Seller',
          itemTitle: listing.title,
        ),
      ),
    );
  }

  Widget _contactActions(BuildContext context) {
    if (listing.userId == AuthService().currentUserId &&
        AuthService().currentUserId > 0) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Your listing', textAlign: TextAlign.center),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: listing.status == 'active'
                  ? () => _openChat(context)
                  : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text(
                'Chat with Seller',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF087CF5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.phone_rounded, size: 18),
              label: Text(
                'Call Seller',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
              ),
              onPressed: () {
                if (listing.hidePhone || listing.phoneNumber == null) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Row(
                        children: [
                          const Icon(
                            Icons.security_rounded,
                            color: Color(0xFF087CF5),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Privacy Protected',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      content: Text(
                        'This seller chose to keep their direct phone number private. You can connect with them instantly using in-app chat.',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF087CF5),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openChat(context);
                          },
                          child: const Text('Open Chat'),
                        ),
                      ],
                    ),
                  );
                } else {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(
                              0xFF087CF5,
                            ).withAlpha(20),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Color(0xFF087CF5),
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            listing.sellerName ?? 'Verified Seller',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Direct Contact',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  listing.phoneNumber!,
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    color: Color(0xFF087CF5),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: listing.phoneNumber!),
                                    );
                                    Navigator.pop(ctx);
                                    AppNotice.show(
                                      context,
                                      SnackBar(
                                        content: Text(
                                          'Phone number copied: ${listing.phoneNumber}',
                                        ),
                                        backgroundColor: const Color(
                                          0xFF10B981,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFF087CF5),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('In-App Chat'),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _openChat(context);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF087CF5),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.phone_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Call now'),
                                  onPressed: () async {
                                    final uri = Uri(
                                      scheme: 'tel',
                                      path: listing.phoneNumber!,
                                    );
                                    try {
                                      final opened = await launchUrl(uri);
                                      if (!opened && context.mounted) {
                                        AppNotice.show(
                                          context,
                                          const SnackBar(
                                            content: Text(
                                              'No phone app available. Use the copy button to save this number.',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (_) {
                                      if (context.mounted)
                                        AppNotice.show(
                                          context,
                                          const SnackBar(
                                            content: Text(
                                              'Unable to open the phone app. You can copy the number instead.',
                                            ),
                                          ),
                                        );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'OJIO Safety: Never share OTPs or pay token amounts before inspecting the item in person.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
