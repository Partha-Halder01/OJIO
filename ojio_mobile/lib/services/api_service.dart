import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../core/api_config.dart';
import '../core/marketplace_location.dart';
import 'auth_service.dart';

class ApiService {
  static final http.Client _sharedReadClient = http.Client();
  static List<CategoryModel>? _categoryCache;
  static DateTime? _categoryCacheTime;
  static Future<List<CategoryModel>>? _categoryRequest;
  final http.Client? _client;
  final bool _cacheCategories;
  ApiService({http.Client? client, bool? cacheCategories})
    : _client = client,
      _cacheCategories = cacheCategories ?? client == null;

  @visibleForTesting
  static void clearCategoryCache() {
    _categoryCache = null;
    _categoryCacheTime = null;
    _categoryRequest = null;
  }

  // Primary base URL
  static const String _primaryUrl = ApiConfig.baseUrl;

  static const String _activeUrl = _primaryUrl;

  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (AuthService().token != null) {
      headers['Authorization'] = 'Bearer ${AuthService().token}';
    }
    return headers;
  }

  Uri _buildUri(
    String baseUrl,
    String endpoint, [
    Map<String, String>? params,
  ]) {
    final cleanParams = (params != null && params.isNotEmpty) ? params : null;
    final baseUri = Uri.parse('$baseUrl$endpoint');
    return cleanParams != null
        ? baseUri.replace(queryParameters: cleanParams)
        : baseUri;
  }

  Future<http.Response> _getWithFallback(
    String endpoint, [
    Map<String, String>? params,
  ]) async {
    final uri = _buildUri(_activeUrl, endpoint, params);
    final headers = _getHeaders();
    final session = AuthService().token;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await (_client ?? _sharedReadClient)
            .get(uri, headers: headers)
            .timeout(Duration(seconds: kIsWeb ? 12 : 10));
        if (attempt == 1 ||
            ![408, 500, 502, 503, 504].contains(response.statusCode) ||
            session != AuthService().token) {
          return response;
        }
      } on TimeoutException {
        if (attempt == 1 || session != AuthService().token) rethrow;
      } on http.ClientException {
        if (attempt == 1 || session != AuthService().token) rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (session != AuthService().token) {
        throw const ApiException('Account changed. Please retry.', 401);
      }
    }
    throw StateError('Read request did not complete.');
  }

  Future<http.Response> _postWithFallback(
    String endpoint,
    Map<String, dynamic> body, {
    String method = 'POST',
  }) async {
    Future<http.Response> doRequest(String baseUrl) {
      final uri = Uri.parse('$baseUrl$endpoint');
      final encoded = jsonEncode(body);
      final timeout = const Duration(seconds: 35);
      if (method == 'PUT') {
        return (_client?.put(uri, headers: _getHeaders(), body: encoded) ??
                http.put(uri, headers: _getHeaders(), body: encoded))
            .timeout(timeout);
      }
      if (method == 'DELETE') {
        return (_client?.delete(uri, headers: _getHeaders(), body: encoded) ??
                http.delete(uri, headers: _getHeaders(), body: encoded))
            .timeout(timeout);
      }
      return (_client?.post(uri, headers: _getHeaders(), body: encoded) ??
              http.post(uri, headers: _getHeaders(), body: encoded))
          .timeout(timeout);
    }

    try {
      return await doRequest(_activeUrl);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> registerPushDevice(
    String deviceKey,
    String deviceToken,
    String sessionToken, {
    required bool chatEnabled,
    bool marketingEnabled = false,
  }) async {
    final response =
        await (_client?.post(
                  Uri.parse('$_activeUrl/user/push-device'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'Authorization': 'Bearer $sessionToken',
                  },
                  body: jsonEncode({
                    'device_key': deviceKey,
                    'token': deviceToken,
                    'chat_enabled': chatEnabled,
                    'marketing_enabled': marketingEnabled,
                  }),
                ) ??
                http.post(
                  Uri.parse('$_activeUrl/user/push-device'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'Authorization': 'Bearer $sessionToken',
                  },
                  body: jsonEncode({
                    'device_key': deviceKey,
                    'token': deviceToken,
                    'chat_enabled': chatEnabled,
                    'marketing_enabled': marketingEnabled,
                  }),
                ))
            .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(response), response.statusCode);
    }
  }

  Future<void> unregisterPushDevice(
    String deviceKey,
    String sessionToken,
  ) async {
    final response =
        await (_client?.delete(
                  Uri.parse('$_activeUrl/user/push-device'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'Authorization': 'Bearer $sessionToken',
                  },
                  body: jsonEncode({'device_key': deviceKey}),
                ) ??
                http.delete(
                  Uri.parse('$_activeUrl/user/push-device'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'Authorization': 'Bearer $sessionToken',
                  },
                  body: jsonEncode({'device_key': deviceKey}),
                ))
            .timeout(const Duration(seconds: 5));
    // An expired session is already unable to receive session-bound pushes.
    if (response.statusCode != 401 &&
        (response.statusCode < 200 || response.statusCode >= 300)) {
      throw ApiException(_errorMessage(response), response.statusCode);
    }
  }

  Future<List<CategoryModel>> fetchCategories() async {
    if (!_cacheCategories) return _fetchCategories();
    if (_categoryCache != null &&
        DateTime.now().difference(_categoryCacheTime!) <
            const Duration(minutes: 1)) {
      return _categoryCache!;
    }
    if (_categoryRequest != null) return _categoryRequest!;
    final request = _fetchCategories();
    _categoryRequest = request;
    try {
      return await request;
    } finally {
      if (identical(_categoryRequest, request)) _categoryRequest = null;
    }
  }

  Future<List<CategoryModel>> _fetchCategories() async {
    try {
      final res = await _getWithFallback('/categories');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['data'] as List;
        final categories = List<CategoryModel>.unmodifiable(
          list.map((c) => CategoryModel.fromJson(c)),
        );
        if (_cacheCategories) {
          _categoryCache = categories;
          _categoryCacheTime = DateTime.now();
        }
        return categories;
      }
    } catch (e) {
      debugPrint('Categories load error: $e');
    }
    return _cacheCategories ? (_categoryCache ?? []) : [];
  }

  Future<List<BannerModel>> fetchBanners() async {
    try {
      final res = await _getWithFallback('/banners');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['data'] as List;
        return list.map((b) => BannerModel.fromJson(b)).toList();
      }
    } catch (e) {
      debugPrint('Banners load error: $e');
    }
    return [];
  }

  Future<List<ListingModel>> fetchListings({
    int? categoryId,
    String? city,
    String? query,
    double? latitude,
    double? longitude,
    double radius = 50,
    String? feed,
    int page = 1,
    double? minPrice,
    double? maxPrice,
    bool throwOnError = false,
  }) async {
    try {
      Map<String, String> params = {};
      if (categoryId != null) params['category_id'] = categoryId.toString();
      if (city != null && city.isNotEmpty) params['city'] = city;
      if (query != null && query.isNotEmpty) params['query'] = query;
      if (latitude != null) params['latitude'] = latitude.toString();
      if (longitude != null) params['longitude'] = longitude.toString();
      if (latitude != null && longitude != null) params['radius'] = '$radius';
      if (feed != null) params['feed'] = feed;
      params['page'] = '$page';
      if (minPrice != null) params['min_price'] = '$minPrice';
      if (maxPrice != null) params['max_price'] = '$maxPrice';

      final res = await _getWithFallback('/listings', params);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['data']['data'] as List;
        return list.map((item) => ListingModel.fromJson(item)).toList();
      }
      if (throwOnError) throw ApiException(_errorMessage(res), res.statusCode);
    } catch (e) {
      if (throwOnError) rethrow;
      debugPrint('Listings load error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> fetchMyAdsSnapshot() async {
    final data = await _successResponse(
      await _getWithFallback('/user/my-ads', null),
    );
    if (data['data'] is! List)
      throw const ApiException('Unable to load your ads. Please retry.', 502);
    return data;
  }

  Future<List<String>> fetchSearchSuggestions(
    String query, {
    int? categoryId,
    String? city,
    double? latitude,
    double? longitude,
    double radius = 50,
  }) async {
    final response = await _getWithFallback('/listings/suggestions', {
      'query': query.trim(),
      if (categoryId != null) 'category_id': '$categoryId',
      if (city != null) 'city': city,
      if (latitude != null) 'latitude': '$latitude',
      if (longitude != null) 'longitude': '$longitude',
      if (latitude != null && longitude != null) 'radius': '$radius',
    });
    if (response.statusCode != 200)
      throw ApiException(_errorMessage(response), response.statusCode);
    return (jsonDecode(response.body)['data'] as List).cast<String>();
  }

  Future<Map<String, dynamic>> fetchLegalDocument(String slug) async {
    final response = await _getWithFallback('/legal/$slug');
    if (response.statusCode != 200)
      throw ApiException(_errorMessage(response), response.statusCode);
    return Map<String, dynamic>.from(jsonDecode(response.body)['data']);
  }

  Future<bool> fetchAdUpdates() async {
    final data = await _successResponse(
      await _getWithFallback('/user/my-ads/updates', null),
    );
    return data['has_updates'] == true;
  }

  Future<bool> readAdUpdates(List<Map<String, dynamic>> updates) async {
    final data = await _successResponse(
      await _postWithFallback('/user/my-ads/updates/read', {
        'updates': updates,
      }),
    );
    return data['has_updates'] == true;
  }

  Future<Map<String, dynamic>> _successResponse(http.Response response) async {
    if (response.statusCode == 401) await AuthService().logout();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(response), response.statusCode);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['status'] != 'success') {
      throw const ApiException(
        'Unable to complete the request. Please retry.',
        502,
      );
    }
    return decoded;
  }

  Future<List<ListingModel>> fetchMyListings() async {
    try {
      final res = await _getWithFallback('/user/my-ads', null);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final dynamic raw = data['data'];
        final List<ListingModel> result = [];

        if (raw is List) {
          for (final item in raw) {
            if (item is Map) {
              result.add(
                ListingModel.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          }
        } else if (raw is Map && raw['data'] is List) {
          for (final item in raw['data']) {
            if (item is Map) {
              result.add(
                ListingModel.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          }
        }
        return result;
      }
    } catch (e) {
      debugPrint('My ads load error: $e');
    }
    return <ListingModel>[];
  }

  Future<bool> createListing(Map<String, dynamic> data) async {
    try {
      final res = await _postWithFallback('/listings', data);
      if (res.statusCode == 201 || res.statusCode == 200) {
        return true;
      } else if (res.statusCode == 402) {
        throw Exception('payment_required');
      } else {
        if (res.statusCode == 401) await AuthService().logout();
        final error = jsonDecode(res.body) as Map<String, dynamic>;
        throw Exception(
          error['message'] ?? 'Unable to publish this ad. Please retry.',
        );
      }
    } catch (e) {
      debugPrint('Error creating listing: $e');
      rethrow;
    }
  }

  Future<bool> updateListing(int id, Map<String, dynamic> data) async {
    try {
      final res = await _postWithFallback(
        '/listings/' + id.toString(),
        data,
        method: 'POST',
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return true;
      } else {
        debugPrint(
          'Update listing response: ' +
              res.statusCode.toString() +
              ' -> ' +
              res.body,
        );
      }
    } catch (e) {
      debugPrint('Error updating listing: ' + e.toString());
    }
    return false;
  }

  Future<bool> markListingAsSold(int id) async {
    try {
      final res = await _postWithFallback(
        '/listings/$id/sold',
        {},
        method: 'PUT',
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error marking listing as sold: $e');
    }
    return false;
  }

  Future<bool> deleteListing(int id) async {
    try {
      final res = await _postWithFallback(
        '/listings/$id',
        {},
        method: 'DELETE',
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting listing: $e');
    }
    return false;
  }

  Future<List<ChatThreadModel>> fetchChatThreads({
    bool throwOnError = false,
  }) async {
    try {
      final res = await _getWithFallback('/chats', null);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['data'] as List;
        return list.map((t) => ChatThreadModel.fromJson(t)).toList();
      }
      if (throwOnError)
        throw ApiException(
          'Unable to refresh chats. Please retry.',
          res.statusCode,
        );
    } catch (e) {
      if (throwOnError) rethrow;
      debugPrint('Error fetching chat threads: $e');
    }
    return [];
  }

  Future<ChatThreadModel?> fetchChatMessages(int threadId) async {
    try {
      final res = await _getWithFallback('/chats/$threadId/messages', null);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final threadJson = data['thread'] as Map<String, dynamic>;
        threadJson['messages'] = data['messages'];
        return ChatThreadModel.fromJson(threadJson);
      }
    } catch (e) {
      debugPrint('Error fetching chat messages: $e');
    }
    return null;
  }

  Future<ChatMessageModel?> sendMessage(
    int listingId,
    String message, {
    int? threadId,
  }) async {
    try {
      final Map<String, dynamic> body = {'message': message};
      if (threadId != null && threadId > 0) body['thread_id'] = threadId;
      if (listingId > 0) body['listing_id'] = listingId;

      final res = await _postWithFallback('/chats/send', body);
      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return ChatMessageModel.fromJson(data['data']);
      } else {
        debugPrint('Send message response: ${res.statusCode} -> ${res.body}');
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
    return null;
  }

  Map<String, dynamic> _authResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(response), response.statusCode);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['status'] != 'success' ||
        decoded['token'] is! String ||
        (decoded['token'] as String).isEmpty ||
        decoded['user'] is! Map<String, dynamic> ||
        decoded['user']['id'] is! int ||
        decoded['user']['id'] <= 0) {
      throw const ApiException('Unable to sign in. Please retry.', 502);
    }
    return decoded;
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    return _authResponse(
      await _postWithFallback('/auth/login', {
        'login': email.trim(),
        'password': password,
      }),
    );
  }

  Future<Map<String, dynamic>?> register(
    String name,
    String email,
    String password, {
    String? phone,
  }) async {
    return _authResponse(
      await _postWithFallback('/auth/register', {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        if (phone != null) 'phone': phone.trim(),
      }),
    );
  }

  Future<Map<String, dynamic>?> updateProfile(
    String name,
    String phone,
    String city,
    String state,
    String country,
  ) async {
    return _successResponse(
      await _postWithFallback('/user/profile', {
        'name': name,
        'phone': phone,
        'city': city,
        'state': state,
        'country': country,
      }),
    );
  }

  Future<Map<String, dynamic>> updateProfileDetails(
    String name,
    String phone,
  ) async {
    return _successResponse(
      await _postWithFallback('/user/profile', {'name': name, 'phone': phone}),
    );
  }

  Future<Map<String, dynamic>> updateLocation(
    MarketplaceLocation location,
  ) async {
    return _successResponse(
      await _postWithFallback('/user/location', {
        'city': location.city,
        'state': location.state,
        'country': location.country,
        'latitude': location.latitude,
        'longitude': location.longitude,
      }),
    );
  }

  // Coupons & Offers APIs
  Future<List<dynamic>> getCoupons() async {
    try {
      final res = await _getWithFallback('/coupons');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          return data['data'] as List<dynamic>;
        }
      }
    } catch (e) {
      debugPrint('Error fetching coupons: ');
    }
    return [];
  }

  Future<Map<String, dynamic>?> validateCoupon(
    String code,
    double amount,
  ) async {
    try {
      final res = await _postWithFallback('/coupons/validate', {
        'code': code,
        'amount': amount,
      });
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          return data['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('Error validating coupon: ');
    }
    return null;
  }

  Future<Map<String, dynamic>?> changePassword(
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) async {
    try {
      final res = await _postWithFallback('/user/change-password', {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': confirmPassword,
      });
      return jsonDecode(res.body);
    } catch (e) {
      debugPrint('Change password err: ');
    }
    return null;
  }

  Future<Map<String, dynamic>?> firebaseLogin({
    required String email,
    String? name,
    String? firebaseUid,
    String? avatar,
    String? phone,
    String? idToken,
  }) async {
    if (idToken == null || idToken.isEmpty) {
      throw const ApiException(
        'Google did not return a sign-in credential. Please retry.',
        401,
      );
    }
    try {
      final res = await _postWithFallback('/auth/firebase-login', {
        'email': email,
        'name': name,
        'firebase_uid': firebaseUid,
        'avatar': avatar,
        'phone': phone,
        'id_token': idToken,
      });
      return _authResponse(res);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<PremiumPackageModel>> fetchPackages() async {
    try {
      final res = await _getWithFallback('/packages');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['data'] is List) {
          return (data['data'] as List)
              .map((p) => PremiumPackageModel.fromJson(p))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching packages: ');
    }
    return [];
  }

  Future<Map<String, dynamic>> verifyPayment({
    required int packageId,
    required String paymentId,
    String? orderId,
    String? signature,
    String? couponCode,
    double? discountAmount,
  }) async {
    return _paymentData(
      await _postWithFallback('/monetization/verify-payment', {
        'package_id': packageId,
        'razorpay_payment_id': paymentId,
        'razorpay_order_id': orderId,
        'razorpay_signature': signature,
        if (couponCode != null) 'coupon_code': couponCode,
        if (discountAmount != null) 'discount_amount': discountAmount,
      }),
    );
  }

  Future<UserModel?> fetchUserProfile() async {
    final session = AuthService().token;
    if (!AuthService().isAuthenticated) return null;
    try {
      final res = await _getWithFallback('/user/profile');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (session == AuthService().token &&
            data['user'] is Map &&
            data['user']['id'] == AuthService().currentUserId) {
          final user = UserModel.fromJson(data['user']);
          await AuthService().updateUser(data['user']);
          return user;
        }
      }
    } catch (e) {
      debugPrint('Fetch profile exception: ');
    }
    return null;
  }

  Future<int> openChat(int listingId) async {
    final data = await _paymentData(
      await _postWithFallback('/chats/open', {'listing_id': listingId}),
    );
    return int.parse(data['thread_id'].toString());
  }

  Future<Map<String, dynamic>> wallet() async {
    final response = await _getWithFallback('/wallet');
    return _paymentData(response);
  }

  Future<Map<String, dynamic>> reverseLocation(
    double latitude,
    double longitude,
  ) async {
    return _paymentData(
      await _getWithFallback('/locations/reverse', {
        'latitude': '$latitude',
        'longitude': '$longitude',
      }),
    );
  }

  Future<Map<String, dynamic>> paymentOrder({
    int? packageId,
    int? amountPaise,
    String? couponCode,
  }) async {
    final response = await _postWithFallback(
      amountPaise != null ? '/wallet/topup' : '/monetization/order',
      {
        if (packageId != null) 'package_id': packageId,
        if (amountPaise != null) 'amount_paise': amountPaise,
        if (couponCode != null) 'coupon_code': couponCode,
      },
    );
    return _paymentData(response);
  }

  Future<Map<String, dynamic>> payWithWallet(
    int packageId,
    String requestId, {
    String? couponCode,
  }) async {
    final session = AuthService().token;
    final data = await _paymentData(
      await _postWithFallback('/monetization/wallet', {
        'package_id': packageId,
        'request_id': requestId,
        if (couponCode != null) 'coupon_code': couponCode,
      }),
    );
    if (session != AuthService().token ||
        data['status'] != 'paid' ||
        data['provider'] != 'wallet' ||
        data['purpose'] != 'premium' ||
        data['user'] is! Map ||
        data['user']['id'] != AuthService().currentUserId) {
      throw const ApiException(
        'Wallet purchase has not been confirmed. Please check your balance before trying again.',
        422,
      );
    }
    await AuthService().updateUser(Map<String, dynamic>.from(data['user']));
    return data;
  }

  Future<Map<String, dynamic>> reconcilePayment(int orderId) async {
    return _paymentData(
      await _postWithFallback('/payments/$orderId/reconcile', {}),
    );
  }

  String _errorMessage(http.Response response) {
    if (response.statusCode == 404 || response.statusCode == 405) {
      return 'This feature is unavailable on the connected server. Please update the backend and retry.';
    }
    if (response.statusCode >= 500) {
      return 'The server could not complete this request. Please try again shortly.';
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final errors = decoded['errors'];
        if (errors is Map && errors.isNotEmpty && errors.values.first is List) {
          return (errors.values.first as List).first.toString();
        }
        if (decoded['message'] is String) return decoded['message'];
      }
    } catch (_) {}
    return 'Unable to complete request. Please retry.';
  }

  Future<Map<String, dynamic>> _paymentData(http.Response response) async {
    if (response.statusCode == 401) {
      await AuthService().logout();
      throw const ApiException(
        'Your session has expired. Please log in again.',
        401,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(response), response.statusCode);
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const ApiException(
        'The server returned an invalid response. Please retry.',
        502,
      );
    }
    if (decoded is! Map<String, dynamic> || decoded['data'] is! Map) {
      throw const ApiException(
        'The server returned an invalid response. Please retry.',
        502,
      );
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['status'] != 'success') {
      throw Exception(
        decoded['message'] ?? 'Unable to complete request. Please retry.',
      );
    }
    return Map<String, dynamic>.from(decoded['data'] as Map);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}
