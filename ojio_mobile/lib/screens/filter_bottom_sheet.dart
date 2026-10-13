import 'package:flutter/material.dart';
import '../core/constants.dart';

class FilterBottomSheet extends StatefulWidget {
  final Function(Map<String, dynamic> filters) onApply;
  final RangeValues initialPriceRange;
  final double initialRadius;
  final bool hasCoordinates;

  const FilterBottomSheet({
    super.key,
    required this.onApply,
    this.initialPriceRange = const RangeValues(0, 5000000),
    this.initialRadius = 50,
    this.hasCoordinates = true,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late RangeValues _priceRange;
  late double _radiusKm;

  @override
  void initState() {
    super.initState();
    _priceRange = widget.initialPriceRange;
    _radiusKm = widget.initialRadius;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filters & Radius',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppConstants.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _priceRange = const RangeValues(0, 5000000);
                      _radiusKm = 50;
                    });
                  },
                  child: const Text(
                    'Reset All',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Distance / Radius Filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Search Distance',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  widget.hasCoordinates
                      ? 'Within ${_radiusKm.round()} km'
                      : 'Selected city',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryColor,
                  ),
                ),
              ],
            ),
            Slider(
              value: _radiusKm,
              min: 5,
              max: 100,
              divisions: 19,
              activeColor: AppConstants.primaryColor,
              onChanged: widget.hasCoordinates
                  ? (val) => setState(() => _radiusKm = val)
                  : null,
            ),
            const SizedBox(height: 12),

            // Price Range Filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Price Range',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '₹${(_priceRange.start / 1000).round()}k - ${_priceRange.end == 5000000 ? 'Any' : '₹${(_priceRange.end / 1000).round()}k'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryColor,
                  ),
                ),
              ],
            ),
            RangeSlider(
              values: _priceRange,
              min: 0,
              max: 5000000,
              divisions: 20,
              activeColor: AppConstants.primaryColor,
              onChanged: (val) => setState(() => _priceRange = val),
            ),
            const SizedBox(height: 16),

            // Apply Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  widget.onApply({
                    'radius': _radiusKm,
                    'min_price': _priceRange.start,
                    'max_price': _priceRange.end,
                  });
                  Navigator.pop(context);
                },
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
