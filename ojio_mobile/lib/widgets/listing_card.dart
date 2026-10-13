import 'premium_badge.dart';
import 'app_image_view.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../screens/listing_detail_screen.dart';

class ListingCard extends StatelessWidget {
  final ListingModel listing;

  const ListingCard({super.key, required this.listing});

  String _buildSpecsLine(ListingModel item) {
    List<String> parts = [];
    final attrs = item.attributes;
    if (attrs.isNotEmpty) {
      if (attrs['year'] != null) parts.add(attrs['year'].toString());
      if (attrs['km_driven'] != null) parts.add(attrs['km_driven'].toString());
      if (attrs['fuel'] != null) parts.add(attrs['fuel'].toString());
      if (attrs['storage'] != null) parts.add(attrs['storage'].toString());
      if (attrs['brand'] != null && parts.length < 2)
        parts.add(attrs['brand'].toString());
    }

    if (parts.isEmpty) {
      if (item.categoryName != null && item.categoryName!.isNotEmpty) {
        parts.add(item.categoryName!);
      }
      parts.add('Verified Deal');
    }

    return parts.take(2).join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final item = listing;
    String rawImg = item.images.isNotEmpty
        ? item.images.first
        : (item.primaryImageUrl ?? '');
    String imageUrl = ListingModel.sanitizeImageUrl(
      rawImg,
      categorySlug: item.categorySlug,
      title: item.title,
    );

    // Using $ as in the user's design image, though currency can be changed if needed
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF1F1F1), width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ListingDetailScreen(listing: item),
              ),
            );
          },
          borderRadius: BorderRadius.circular(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // IMAGE CONTAINER
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(4.5),
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      SizedBox.expand(
                        key: const ValueKey('listing-card-image-area'),
                        child: AppImageView(
                          url: imageUrl,
                          fit: BoxFit.contain,
                          categorySlug: item.categorySlug,
                          title: item.title,
                        ),
                      ),

                      Positioned(
                        top: 8,
                        left: 8,
                        child: PremiumBadge(
                          premium: item.sellerIsPremium,
                          diamond: item.sellerHasDiamondBadge,
                          until: item.sellerPremiumUntil,
                          diamondUntil: item.sellerDiamondBadgeUntil,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // DETAILS SECTION
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // TITLE
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),

                    // SUBTITLE (Location)
                    Text(
                      item.locality != null && item.locality!.isNotEmpty
                          ? item.locality!.toUpperCase()
                          : item.city.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // PRICE
                    Text(
                      currency.format(item.price),
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
