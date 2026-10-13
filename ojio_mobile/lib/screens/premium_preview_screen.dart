import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/listing_card.dart';
import '../widgets/premium_badge.dart';

/// Visual demo only: no auth mutation, API calls, wallet credit or posting rights.
class PremiumPreviewScreen extends StatefulWidget {
  const PremiumPreviewScreen({super.key});
  @override
  State<PremiumPreviewScreen> createState() => _PremiumPreviewScreenState();
}

class _PremiumPreviewScreenState extends State<PremiumPreviewScreen> {
  String _mode = 'diamond';
  late final Future<String> _demoImage = _loadImage();

  Future<String> _loadImage() async {
    final image = await rootBundle.load('assets/images/cat_mobiles.png');
    return 'data:image/png;base64,${base64Encode(image.buffer.asUint8List(image.offsetInBytes, image.lengthInBytes))}';
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final until =
        (_mode == 'expired'
                ? DateTime.now().subtract(const Duration(days: 1))
                : DateTime.now().add(const Duration(days: 30)))
            .toUtc()
            .toIso8601String();
    final diamond = _mode != 'premium';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium preview'),
        backgroundColor: const Color(0xFF03172D),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF03172D),
              child: Stack(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 56, 24, 24),
                    child: Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: Color(0xFF087CF5),
                            child: Text(
                              'DS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Demo Seller',
                            style: TextStyle(color: Colors.white, fontSize: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 16,
                    child: PremiumBadge(
                      premium: true,
                      diamond: diamond,
                      until: until,
                      diamondUntil: until,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Preview only. No payment, wallet or posting allowance changes.',
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final mode in ['diamond', 'premium', 'expired'])
                  ChoiceChip(
                    label: Text(
                      mode == 'diamond'
                          ? 'Diamond'
                          : mode == 'premium'
                          ? 'Premium'
                          : 'Expired',
                    ),
                    selected: _mode == mode,
                    onSelected: (_) => setState(() => _mode = mode),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 220,
                height: 300,
                child: IgnorePointer(
                  child: FutureBuilder<String>(
                    future: _demoImage,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      return ListingCard(
                        listing: ListingModel(
                          id: -1,
                          title: 'Demo listing',
                          price: 15000,
                          city: 'Kolkata',
                          categorySlug: 'mobiles',
                          primaryImageUrl: snapshot.data,
                          sellerName: 'Demo Seller',
                          createdAt: DateTime.now(),
                          sellerIsPremium: true,
                          sellerHasDiamondBadge: diamond,
                          sellerPremiumUntil: until,
                          sellerDiamondBadgeUntil: until,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
