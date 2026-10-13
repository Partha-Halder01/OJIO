import '../widgets/app_notice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/marketplace_location.dart';
import '../main.dart' show MainNavigationScreen;
import '../services/api_service.dart';
import '../services/auth_service.dart';

class CityLocationScreen extends LocationSelectScreen {
  const CityLocationScreen({super.key}) : super(returnSelection: true);
}

class LocationSelectScreen extends StatefulWidget {
  final bool returnSelection;
  const LocationSelectScreen({super.key, this.returnSelection = false});

  @override
  State<LocationSelectScreen> createState() => _LocationSelectScreenState();
}

class _LocationSelectScreenState extends State<LocationSelectScreen> {
  bool _isDetecting = false;
  bool _isSaving = false;
  String _searchQuery = '';
  final _cityController = TextEditingController();

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  final List<Map<String, String>> _popularCities = [
    {'name': 'Mumbai', 'state': 'Maharashtra', 'ads': '32,100+ ads'},
    {'name': 'Delhi NCR', 'state': 'Delhi', 'ads': '28,500+ ads'},
    {'name': 'Bengaluru', 'state': 'Karnataka', 'ads': '22,400+ ads'},
    {'name': 'Hyderabad', 'state': 'Telangana', 'ads': '18,300+ ads'},
    {'name': 'Pune', 'state': 'Maharashtra', 'ads': '11,900+ ads'},
    {'name': 'Kolkata', 'state': 'West Bengal', 'ads': '14,200+ ads'},
    {'name': 'Chennai', 'state': 'Tamil Nadu', 'ads': '13,500+ ads'},
    {'name': 'Ahmedabad', 'state': 'Gujarat', 'ads': '9,800+ ads'},
    {'name': 'Jaipur', 'state': 'Rajasthan', 'ads': '7,400+ ads'},
    {'name': 'Chandigarh', 'state': 'Punjab', 'ads': '6,200+ ads'},
  ];

  Future<void> _selectCityAndEnter(
    String city, {
    double? latitude,
    double? longitude,
    String? state,
    String? country,
  }) async {
    if (_isSaving || city.trim().isEmpty) return;
    setState(() => _isSaving = true);
    final location = latitude != null && longitude != null
        ? MarketplaceLocation(
            city.trim(),
            latitude: latitude,
            longitude: longitude,
            state: state,
            country: country ?? 'India',
          )
        : MarketplaceLocation.forCity(city.trim());
    try {
      await AuthService().selectLocation(location);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppNotice.show(
        context,
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
      return;
    }
    if (!mounted) return;
    if (widget.returnSelection) {
      Navigator.pop(context, location);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainNavigationScreen(initialCity: city),
      ),
    );
  }

  Future<void> _autoDetectGPS() async {
    if (_isDetecting || _isSaving) return;
    setState(() => _isDetecting = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String? cityName;
      String? state;
      String? country;
      try {
        if (kIsWeb) {
          throw UnsupportedError('Use server reverse geocoding on web');
        }
        List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          cityName =
              [
                    place.locality,
                    place.subAdministrativeArea,
                    place.administrativeArea,
                  ]
                  .whereType<String>()
                  .where((name) => name.trim().isNotEmpty)
                  .firstOrNull;
          state = place.administrativeArea;
          country = place.country;
        }
      } catch (_) {}
      if (cityName == null) {
        final detected = await ApiService().reverseLocation(
          position.latitude,
          position.longitude,
        );
        cityName = detected['city'] as String?;
        state = detected['state'] as String?;
        country = detected['country'] as String?;
      }
      if (cityName == null || cityName.trim().isEmpty) {
        throw Exception(
          'Unable to detect your city. Please select it manually.',
        );
      }

      if (mounted) {
        setState(() => _isDetecting = false);
        await _selectCityAndEnter(
          cityName,
          latitude: position.latitude,
          longitude: position.longitude,
          state: state ?? MarketplaceLocation.forCity(cityName).state,
          country: country,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDetecting = false);
        AppNotice.show(context, SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _popularCities
        .where(
          (c) =>
              c['name']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              c['state']!.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0.5,
        title: Text(
          widget.returnSelection
              ? 'City & Location'
              : 'Choose Your Marketplace',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textMain,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(50),
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
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Use Current Location',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Discover deals within your immediate radius',
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _isDetecting || _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _autoDetectGPS,
                            child: Text(
                              'Auto Detect',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search state, city or district...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'POPULAR REGIONS',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: filtered.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 56, color: AppColors.border),
              itemBuilder: (context, index) {
                final city = filtered[index];
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F3FF),
                    child: Icon(
                      Icons.location_city_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    city['name']!,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color:
                          AuthService().location.value?.city.toLowerCase() ==
                              city['name']!.toLowerCase()
                          ? AppColors.primary
                          : AppColors.textMain,
                    ),
                  ),
                  subtitle: Text(
                    city['state']!,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      AuthService().location.value?.city.toLowerCase() ==
                              city['name']!.toLowerCase()
                          ? 'Selected'
                          : 'Select',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  onTap: _isSaving || _isDetecting
                      ? null
                      : () => _selectCityAndEnter(city['name']!),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cityController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Other city',
                        hintText: 'Enter your city',
                      ),
                      onSubmitted: _isSaving || _isDetecting
                          ? null
                          : _selectCityAndEnter,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving || _isDetecting
                        ? null
                        : () => _selectCityAndEnter(_cityController.text),
                    child: const Text('Set'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
