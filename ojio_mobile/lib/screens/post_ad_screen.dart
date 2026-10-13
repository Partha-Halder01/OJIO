import '../widgets/app_notice.dart';
import '../widgets/app_image_view.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/paywall_modal.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import '../core/marketplace_fields.dart';
import '../core/post_ad_location.dart';
import '../services/payment_flow.dart';

class PostAdScreen extends StatefulWidget {
  final ListingModel? editListing;
  final ApiService? api;

  const PostAdScreen({super.key, this.editListing, this.api});

  @override
  State<PostAdScreen> createState() => _PostAdScreenState();
}

class _PostAdScreenState extends State<PostAdScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ApiService _api;
  final String _postRequestId = checkoutRequestId();

  // Wizard Step: 0 = Choose Type, 1 = Choose Subtype, 2 = Fill Details Form
  int _step = 0;

  CategoryModel? _selectedCategory;
  Map<String, dynamic>? _selectedSubtype;
  int? _selectedCategoryId;

  List<CategoryModel> _categories = [];
  bool _isLoadingCategories = true;
  String? _categoryLoadError;

  final TextEditingController _brandCtrl = TextEditingController();
  final TextEditingController _modelCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _isDetectingLocation = false;
  List<String> _detectedPlaces = [];
  String? _detectedTown;
  static const int _maxImages = 3;
  final List<String> _popularCities = [
    'Kolkata',
    'Mumbai',
    'Delhi',
    'Bengaluru',
    'Hyderabad',
    'Chennai',
    'Pune',
    'Ahmedabad',
    'Jaipur',
    'Lucknow',
  ];
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController(
    text: 'Kolkata',
  );
  final TextEditingController _localityCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  bool _isNegotiable = false;
  bool _hidePhone = false;
  bool _isSubmitting = false;

  final List<String> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  bool get _isEditing => widget.editListing != null;

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    AppNotice.show(
      context,
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError ? Colors.red : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 30, left: 24, right: 24),
        duration: const Duration(seconds: 3),
        elevation: 8,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiService();
    _loadCategories();
    if (_isEditing) {
      final item = widget.editListing!;
      _step = 2;
      _titleCtrl.text = item.title;
      _descCtrl.text = item.description ?? "";
      _priceCtrl.text = item.price.toInt().toString();
      _cityCtrl.text = item.city;
      if (item.locality != null) _localityCtrl.text = item.locality!;
      if (item.phoneNumber != null) _phoneCtrl.text = item.phoneNumber!;
      _isNegotiable = item.isNegotiable;
      _hidePhone = item.hidePhone;
      _selectedCategoryId = item.categoryId;
      if (item.attributes.containsKey('brand')) {
        _brandCtrl.text = item.attributes['brand']?.toString() ?? '';
      }
      if (item.attributes.containsKey('model')) {
        _modelCtrl.text = item.attributes['model']?.toString() ?? '';
      }
      if (item.images.isNotEmpty) {
        _selectedImages.addAll(item.images.take(_maxImages));
      } else if (item.primaryImageUrl != null &&
          item.primaryImageUrl!.isNotEmpty) {
        _selectedImages.add(item.primaryImageUrl!);
      }
    } else {
      final currentUser = AuthService().currentUser;
      if (currentUser?.phone != null && currentUser!.phone!.isNotEmpty) {
        _phoneCtrl.text = currentUser.phone!;
      }
    }
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() {
      _isLoadingCategories = true;
      _categoryLoadError = null;
    });
    try {
      final fetched = await _api.fetchCategories();
      final list = fetched
          .where(
            (cat) =>
                cat.slug.toLowerCase() != 'others' &&
                cat.name.toLowerCase() != 'others',
          )
          .toList();

      if (mounted) {
        setState(() {
          _categories = list;
          _isLoadingCategories = false;
          if (list.isEmpty) {
            _categoryLoadError =
                'Posting categories are unavailable. Please retry.';
          }
          if (_isEditing && _selectedCategoryId != null) {
            for (var c in list) {
              if (c.id == _selectedCategoryId) {
                _selectedCategory = c;
                break;
              }
              for (var s in c.subcategories) {
                if (s.id == _selectedCategoryId) {
                  _selectedCategory = c;
                  _selectedSubtype = {
                    'id': s.id,
                    'name': s.name,
                    'slug': s.slug,
                    'brands': s.customAttributesSchema['brand'],
                  };
                  break;
                }
              }
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          _categoryLoadError =
              'Could not load categories. Check your connection and retry.';
        });
      }
    }
  }

  List<Map<String, dynamic>> _getSubtypesForCategory(CategoryModel cat) {
    if (cat.subcategories.isNotEmpty) {
      return cat.subcategories
          .map(
            (s) => {
              'id': s.id,
              'name': s.name,
              'slug': s.slug,
              'brands': s.customAttributesSchema['brand'],
              'iconUrl': s.icon,
              'icon': _getCategoryIcon(s.slug),
            },
          )
          .toList();
    }

    return [
      {
        'id': cat.id,
        'name': 'All in ${cat.name}',
        'slug': cat.slug,
        'brands': cat.customAttributesSchema['brand'],
        'icon': Icons.category_rounded,
      },
    ];
  }

  IconData _getCategoryIcon(String slug) {
    slug = slug.toLowerCase();
    if (slug.contains('car') && !slug.contains('game')) {
      return Icons.directions_car_filled_rounded;
    }
    if (slug.contains('commercial') ||
        slug.contains('truck') ||
        slug.contains('vehicle')) {
      return Icons.local_shipping_rounded;
    }
    if (slug.contains('bike') ||
        slug.contains('scooter') ||
        slug.contains('moped')) {
      return Icons.two_wheeler_rounded;
    }
    if (slug.contains('mobil') ||
        slug.contains('tablet') ||
        slug.contains('phone')) {
      return Icons.smartphone_rounded;
    }
    if (slug.contains('elect') && !slug.contains('vehicle')) {
      return Icons.laptop_chromebook_rounded;
    }
    if (slug.contains('estate') ||
        slug.contains('apartment') ||
        slug.contains('property')) {
      return Icons.apartment_rounded;
    }
    if (slug.contains('job') ||
        slug.contains('work') ||
        slug.contains('career')) {
      return Icons.work_rounded;
    }
    if (slug.contains('furnit') ||
        slug.contains('sofa') ||
        slug.contains('bed')) {
      return Icons.chair_rounded;
    }
    if (slug.contains('fashion') ||
        slug.contains('cloth') ||
        slug.contains('wear')) {
      return Icons.checkroom_rounded;
    }
    if (slug.contains('sport') ||
        slug.contains('fitness') ||
        slug.contains('gym')) {
      return Icons.sports_soccer_rounded;
    }
    if (slug.contains('home') ||
        slug.contains('appliance') ||
        slug.contains('kitchen')) {
      return Icons.kitchen_rounded;
    }
    if (slug.contains('service') ||
        slug.contains('repair') ||
        slug.contains('plumb')) {
      return Icons.handyman_rounded;
    }
    if (slug.contains('book') ||
        slug.contains('education') ||
        slug.contains('study')) {
      return Icons.menu_book_rounded;
    }
    if (slug.contains('pet') ||
        slug.contains('animal') ||
        slug.contains('dog') ||
        slug.contains('cat')) {
      return Icons.pets_rounded;
    }
    if (slug.contains('agri') ||
        slug.contains('farm') ||
        slug.contains('crop')) {
      return Icons.agriculture_rounded;
    }
    if (slug.contains('gaming') ||
        slug.contains('game') ||
        slug.contains('console') ||
        slug.contains('xbox') ||
        slug.contains('ps5')) {
      return Icons.sports_esports_rounded;
    }
    return Icons.grid_view_rounded;
  }

  Color _getCategoryColor(int index) {
    const colors = [
      Color(0xFF087CF5),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
    ];
    return colors[index % colors.length];
  }

  List<String> _getPopularBrandsForCategory() {
    final configured =
        _selectedSubtype?['brands'] ??
        _selectedCategory?.customAttributesSchema['brand'];
    if (configured is List) {
      return {...configured.map((brand) => brand.toString()), 'Other'}.toList();
    }
    return MarketplaceFields.brands(
      _selectedCategory?.slug ?? '',
      _selectedSubtype?['name']?.toString() ?? '',
    );
  }

  void _clearProductSelection() {
    final generatedTitle = [
      _brandCtrl.text,
      _modelCtrl.text,
    ].where((value) => value.isNotEmpty).join(' ');
    if (_titleCtrl.text == generatedTitle) _titleCtrl.clear();
    _brandCtrl.clear();
    _modelCtrl.clear();
    AppNotice.dismiss();
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Please enable location services.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Please allow location access or choose your city manually.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!postAdGpsIsPrecise(position.accuracy)) {
        throw Exception(
          'GPS is approximate. Enable precise location for OJIO and retry, '
          'or enter your city and area manually.',
        );
      }
      Map<String, dynamic>? location;
      if (!kIsWeb) {
        try {
          final places = await Geocoding().placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          location = postAdPlacemarkLocation(places);
        } catch (_) {}
      }
      location = await completePostAdLocation(
        location,
        () => _api
            .reverseLocation(position.latitude, position.longitude)
            .timeout(const Duration(seconds: 6)),
      );
      if (!mounted) return;
      final detectedCity = location['city'].toString();
      final detectedArea = location['locality']?.toString() ?? '';
      final places = (location['places'] as List)
          .map((value) => value.toString())
          .toList();
      final metro = _popularCities
          .where(
            (city) =>
                places.any((place) => MarketplaceFields.samePlace(city, place)),
          )
          .firstOrNull;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _detectedPlaces = places;
        _detectedTown = detectedCity;
        _cityCtrl.text = metro ?? detectedCity;
        _localityCtrl.text = detectedArea;
      });
      _showToast(
        detectedArea.isEmpty
            ? 'City detected: ${_cityCtrl.text}. Please enter your correct area; '
                  'the map could not confirm it.'
            : 'Location detected: ${_cityCtrl.text} ($detectedArea). Please check the area.',
      );
    } catch (error) {
      _showToast(
        'Unable to detect location. ${error.toString().replaceFirst('Exception: ', '')}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_selectedImages.length >= _maxImages) {
      _showToast('Maximum 3 images allowed per ad.', isError: true);
      return;
    }
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );
      if (images.isNotEmpty) {
        final availableSlots = _maxImages - _selectedImages.length;
        final toAdd = images.take(availableSlots);
        for (var img in toAdd) {
          final bytes = await img.readAsBytes();
          final b64 = base64Encode(bytes);
          final mime = img.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg';
          if (mounted) {
            setState(() {
              _selectedImages.add('data:$mime;base64,$b64');
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Gallery pick err: $e');
    }
  }

  Future<void> _pickFromCamera() async {
    if (_selectedImages.length >= _maxImages) {
      _showToast('Maximum 3 images allowed per ad.', isError: true);
      return;
    }
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final b64 = base64Encode(bytes);
        final mime = image.name.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';
        if (mounted) {
          setState(() {
            _selectedImages.add('data:$mime;base64,$b64');
          });
        }
      }
    } catch (e) {
      debugPrint('Camera pick err: $e');
    }
  }

  void _showAddImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Item Photos',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF087CF5),
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFECFDF5),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF10B981),
                  ),
                ),
                title: Text(
                  'Take a Photo with Camera',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF1F5F9),
                  child: Icon(Icons.link_rounded, color: Color(0xFF475569)),
                ),
                title: Text(
                  'Enter Web Image URL',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showUrlInputDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUrlInputDialog() {
    final urlCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Image Web URL',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(
            hintText: 'https://images.unsplash.com/...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (urlCtrl.text.trim().isNotEmpty) {
                setState(() => _selectedImages.add(urlCtrl.text.trim()));
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF087CF5),
            ),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAd() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      _showToast('Please select a category', isError: true);
      return;
    }
    if (_selectedImages.isEmpty) {
      _showToast('Please add at least 1 image for your ad', isError: true);
      return;
    }

    if (!AuthService().isAuthenticated) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Log in to post your ad'),
          content: const Text(
            'Your details are ready. Log in to publish, or return home without posting.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'home'),
              child: const Text('Back to home'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'login'),
              child: const Text('Log in'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (action == 'home') {
        Navigator.pop(context);
        return;
      }
      if (action != 'login') return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(returnToPrevious: true),
        ),
      );
      if (!mounted || !AuthService().isAuthenticated) return;
    }
    if ((AuthService().currentUser?.phone ?? '').isEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const SignUpScreen(returnToPrevious: true, completeContact: true),
        ),
      );
      if (!mounted || (AuthService().currentUser?.phone ?? '').isEmpty) return;
    }

    setState(() => _isSubmitting = true);

    final payload = {
      if (!_isEditing) 'post_request_id': _postRequestId,
      'category_id': _selectedCategoryId ?? widget.editListing?.categoryId,
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      'is_negotiable': _isNegotiable,
      'city': _cityCtrl.text.trim().isEmpty ? 'Kolkata' : _cityCtrl.text.trim(),
      'locality': _localityCtrl.text.trim().isEmpty
          ? null
          : _localityCtrl.text.trim(),
      'latitude': _latitude,
      'longitude': _longitude,
      'phone_number': AuthService().currentUser?.phone,
      'hide_phone': _hidePhone,
      'attributes': {
        if (_brandCtrl.text.trim().isNotEmpty) 'brand': _brandCtrl.text.trim(),
        if (_modelCtrl.text.trim().isNotEmpty) 'model': _modelCtrl.text.trim(),
      },
      'images': _selectedImages.isNotEmpty
          ? _selectedImages.take(_maxImages).toList()
          : [
              ListingModel.defaultCategoryPlaceholder(
                _selectedCategory?.slug,
                title: _titleCtrl.text.trim(),
              ),
            ],
    };

    bool success = false;
    String? failureMessage;
    try {
      if (_isEditing) {
        success = await _api.updateListing(widget.editListing!.id, payload);
      } else {
        success = await _api.createListing(payload);
      }
    } catch (e) {
      failureMessage = e.toString().replaceFirst('Exception: ', '');
      if (e.toString().contains('payment_required')) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        if (mounted) {
          PaywallModal.show(
            context,
            onPaymentSuccess: () {
              _submitAd();
            },
          );
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (mounted) {
      if (success) {
        if (!_isEditing) {
          await _api.fetchUserProfile(); // Refresh user quota
        }
        if (!mounted) return;
        _showToast(
          _isEditing
              ? 'Listing updated successfully! Changes are now live.'
              : 'Listing published successfully!',
        );
        Navigator.pop(context, true);
      } else {
        _showToast(
          failureMessage ??
              (_isEditing
                  ? 'Failed to update listing.'
                  : 'Unable to publish. Please check your connection and retry.'),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isEditing || _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _step > 0 && !_isEditing) {
          AppNotice.dismiss();
          setState(() => _step--);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF03172D),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              AppNotice.dismiss();
              if (_step > 0 && !_isEditing) {
                setState(() => _step--);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            _isEditing
                ? 'Edit Listing'
                : _step == 0
                ? 'What are you offering?'
                : _step == 1
                ? 'Choose Subtype'
                : 'Item Details',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ),
        body: _isLoadingCategories
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF087CF5)),
              )
            : _categoryLoadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_categoryLoadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loadCategories,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : _step == 0
            ? _buildTypeBlocksStep()
            : _step == 1
            ? _buildSubtypeBlocksStep()
            : _buildDetailsFormStep(),
      ),
    );
  }

  // STEP 0: Block for Types (Categories)
  @override
  void dispose() {
    for (final controller in [
      _brandCtrl,
      _modelCtrl,
      _titleCtrl,
      _descCtrl,
      _priceCtrl,
      _cityCtrl,
      _localityCtrl,
      _phoneCtrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildTypeBlocksStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHOOSE CATEGORY',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.2,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select the type of item you want to sell',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.15,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                // Different solid colors for blocks
                final List<Color> blockColors = [
                  const Color(0xFF50C8B1), // Teal
                  const Color(0xFFFE9B77), // Orange
                  const Color(0xFF7CA6F6), // Blue
                  const Color(0xFFEE8CD8), // Pink
                  const Color(0xFFB197F4), // Purple
                  const Color(0xFF4BA9B3), // Dark Teal
                  const Color(0xFF81C784), // Light Green
                  const Color(0xFFF6D365), // Yellow
                  const Color(0xFF64748B), // Slate
                ];
                final color = blockColors[index % blockColors.length];
                final icon = _getCategoryIcon(cat.slug);

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (_selectedCategory?.id != cat.id) {
                        _clearProductSelection();
                        _selectedSubtype = null;
                        _selectedCategoryId = null;
                      }
                      _selectedCategory = cat;
                      _step = 1;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: color.withAlpha(50),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          cat.name,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // STEP 1: Block for Subtypes
  Widget _buildSubtypeBlocksStep() {
    final subtypes = _getSubtypesForCategory(_selectedCategory!);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb removed as requested
          Text(
            'SELECT SUBTYPE',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.2,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick the specific sub-category for your ad',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.15,
              ),
              itemCount: subtypes.length,
              itemBuilder: (context, index) {
                final sub = subtypes[index];
                // Different solid colors for blocks
                final List<Color> blockColors = [
                  const Color(0xFF50C8B1), // Teal
                  const Color(0xFFFE9B77), // Orange
                  const Color(0xFF7CA6F6), // Blue
                  const Color(0xFFEE8CD8), // Pink
                  const Color(0xFFB197F4), // Purple
                  const Color(0xFF4BA9B3), // Dark Teal
                  const Color(0xFF81C784), // Light Green
                  const Color(0xFFF6D365), // Yellow
                  const Color(0xFF64748B), // Slate
                ];
                final color =
                    blockColors[(index + 3) %
                        blockColors
                            .length]; // Offset so colors don't match categories perfectly

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedSubtype = sub;
                      if (_selectedCategoryId != sub['id']) {
                        _clearProductSelection();
                      }
                      _selectedCategoryId = sub['id'] as int;
                      _step = 2; // Open the ad form!
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: color.withAlpha(50),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            sub['icon'] as IconData? ?? Icons.category_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            sub['name'] as String,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.white,
                              height: 1.1,
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
        ],
      ),
    );
  }

  // STEP 2: The Details Form
  Widget _buildDetailsFormStep() {
    return SingleChildScrollView(
      key: ValueKey('post-details-$_selectedCategoryId'),
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Category & Subtype Selected Breadcrumb
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF10B981),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_selectedCategory?.name ?? ""}  >  ${_selectedSubtype?["name"] ?? ""}',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _step = 0),
                    child: Text(
                      'Change',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF087CF5),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            if (_getPopularBrandsForCategory().isNotEmpty) ...[
              // 1. Brand / Company Block
              Text(
                'BRAND / COMPANY (SELECT OR WRITE MANUALLY) *',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _getPopularBrandsForCategory().map((b) {
                    final isSelected =
                        _brandCtrl.text.trim().toLowerCase() == b.toLowerCase();
                    return Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 6),
                      child: ChoiceChip(
                        label: Text(
                          b,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFF087CF5).withAlpha(30),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? const Color(0xFF087CF5)
                              : const Color(0xFF334155),
                        ),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF087CF5)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        onSelected: (val) {
                          setState(() {
                            _brandCtrl.text = val ? b : '';
                            if (_titleCtrl.text.isEmpty ||
                                _titleCtrl.text.contains(b)) {
                              _titleCtrl.text =
                                  _brandCtrl.text +
                                  (_modelCtrl.text.isNotEmpty
                                      ? ' ' + _modelCtrl.text
                                      : '');
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brandCtrl,
                      decoration: InputDecoration(
                        hintText:
                            'e.g. ${_getPopularBrandsForCategory().first}',
                        hintStyle: const TextStyle(color: Color(0x806B7785)),
                        labelText: 'Brand / Company',
                        prefixIcon: const Icon(
                          Icons.branding_watermark_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      onChanged: (v) {
                        if (_titleCtrl.text.isEmpty) {
                          _titleCtrl.text =
                              v +
                              (_modelCtrl.text.isNotEmpty
                                  ? ' ' + _modelCtrl.text
                                  : '');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _modelCtrl,
                      decoration: InputDecoration(
                        hintText: MarketplaceFields.modelExample(
                          _selectedCategory?.slug ?? '',
                          _selectedSubtype?['slug'] ?? '',
                        ),
                        hintStyle: const TextStyle(color: Color(0x806B7785)),
                        labelText: 'Model / Variant',
                        prefixIcon: const Icon(
                          Icons.label_outline_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      onChanged: (v) {
                        if (_brandCtrl.text.isNotEmpty &&
                            (_titleCtrl.text.isEmpty ||
                                _titleCtrl.text.startsWith(_brandCtrl.text))) {
                          _titleCtrl.text = _brandCtrl.text + ' ' + v;
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],
            // 2. Photos Section (Max 3 Images)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'UPLOAD PHOTOS (${_selectedImages.length}/3) *',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'Max 3 images',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: const Color(0xFF087CF5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_selectedImages.length < _maxImages)
                    InkWell(
                      onTap: _showAddImageOptions,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFF087CF5),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add_a_photo_rounded,
                              color: Color(0xFF087CF5),
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add Photo',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF087CF5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  ..._selectedImages.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final path = entry.value;
                    return Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          margin: const EdgeInsets.only(right: 10),
                          child: AppImageView(
                            url: path,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(10),
                            categorySlug: _selectedCategory?.slug,
                            title: _titleCtrl.text.trim(),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 14,
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedImages.removeAt(idx)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black87,
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Model Name / Ad Title
            Text(
              'MODEL NAME / AD TITLE *',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: const Color(0xFF64748B),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: MarketplaceFields.titleExample(
                  _selectedCategory?.slug ?? '',
                  _selectedSubtype?['slug'] ?? '',
                ),
                hintStyle: const TextStyle(color: Color(0x806B7785)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter model name or ad title'
                  : null,
            ),
            const SizedBox(height: 18),

            // 3. Price
            Text(
              'PRICE (₹) *',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: const Color(0xFF64748B),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                  fontSize: 16,
                ),
                hintText: 'e.g. 45000',
                hintStyle: const TextStyle(color: Color(0x806B7785)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please enter price' : null,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Checkbox(
                  value: _isNegotiable,
                  onChanged: (val) =>
                      setState(() => _isNegotiable = val ?? false),
                  activeColor: const Color(0xFF087CF5),
                ),
                Text(
                  'Price is negotiable',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 4. Other Details
            Text(
              'OTHER DETAILS / DESCRIPTION *',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: const Color(0xFF64748B),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'Mention condition, year of purchase, included accessories, or reason for selling...',
                hintStyle: const TextStyle(color: Color(0x806B7785)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please write details about your item'
                  : null,
            ),
            const SizedBox(height: 18),

            // 5. Location
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LOCATION *',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    letterSpacing: 1.1,
                  ),
                ),
                InkWell(
                  onTap: _isDetectingLocation ? null : _detectCurrentLocation,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _isDetectingLocation
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF087CF5),
                                ),
                              )
                            : const Icon(
                                Icons.my_location_rounded,
                                size: 14,
                                color: Color(0xFF087CF5),
                              ),
                        const SizedBox(width: 4),
                        Text(
                          _isDetectingLocation
                              ? 'Detecting...'
                              : 'Auto-Fetch City',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF087CF5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _popularCities.map((city) {
                  final isSelected =
                      MarketplaceFields.samePlace(_cityCtrl.text, city) ||
                      _detectedPlaces.any(
                        (p) => MarketplaceFields.samePlace(p, city),
                      );
                  return Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 6),
                    child: ActionChip(
                      label: Text(
                        city,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                      backgroundColor: isSelected
                          ? const Color(0xFF087CF5).withAlpha(25)
                          : Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? const Color(0xFF087CF5)
                            : const Color(0xFF334155),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF087CF5)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      onPressed: () => setState(() {
                        _cityCtrl.text = city;
                        _localityCtrl.clear();
                        _detectedPlaces = [];
                        _detectedTown = null;
                        _latitude = null;
                        _longitude = null;
                      }),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),
            if (_detectedTown != null)
              Wrap(
                spacing: 6,
                children: {_detectedTown!, _localityCtrl.text}
                    .where((place) => place.trim().isNotEmpty)
                    .map(
                      (place) => ChoiceChip(
                        label: Text(place),
                        selected:
                            MarketplaceFields.samePlace(
                              place,
                              _localityCtrl.text,
                            ) ||
                            MarketplaceFields.samePlace(place, _detectedTown!),
                        selectedColor: const Color(0xFFEFF6FF),
                        labelStyle: const TextStyle(color: Color(0xFF087CF5)),
                        onSelected: (_) =>
                            setState(() => _localityCtrl.text = place),
                      ),
                    )
                    .toList(),
              ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityCtrl,
                    onChanged: (_) => setState(() {
                      _detectedPlaces = [];
                      _detectedTown = null;
                      _latitude = null;
                      _longitude = null;
                    }),
                    decoration: InputDecoration(
                      labelText: 'City',
                      prefixIcon: const Icon(
                        Icons.location_city_rounded,
                        color: Color(0xFF64748B),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter city' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _localityCtrl,
                    onChanged: (_) => setState(() {
                      _latitude = null;
                      _longitude = null;
                    }),
                    decoration: InputDecoration(
                      labelText: 'Locality / Area',
                      prefixIcon: const Icon(
                        Icons.pin_drop_rounded,
                        color: Color(0xFF64748B),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 6. Contact Number
            Text(
              'CONTACT NUMBER',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: const Color(0xFF64748B),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.phone_rounded,
                color: Color(0xFF087CF5),
              ),
              title: Text(
                AuthService().currentUser?.phone ??
                    'Contact number added after login',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Uses your profile contact number'),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Checkbox(
                  value: _hidePhone,
                  onChanged: (val) => setState(() => _hidePhone = val ?? false),
                  activeColor: const Color(0xFF087CF5),
                ),
                Expanded(
                  child: Text(
                    'Hide phone number on public listing',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitAd,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF087CF5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _isEditing ? 'Save & Update Ad' : 'Post Ad Now',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
