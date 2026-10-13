import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../core/marketplace_location.dart';
import 'api_service.dart';
import 'my_ads_updates_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String? token;
  UserModel? currentUser;
  final location = ValueNotifier<MarketplaceLocation?>(null);
  final sessionChanges = ValueNotifier<int>(0);
  Future<void> Function(String? oldSession)? onLogout;

  bool get isAuthenticated =>
      token != null && token!.isNotEmpty && currentUser != null;
  int get currentUserId => currentUser?.id ?? 0;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');
    final userStr = prefs.getString('auth_user');
    currentUser = null;
    try {
      if (userStr != null && token != null) {
        currentUser = UserModel.fromJson(jsonDecode(userStr));
      }
    } catch (_) {
      await logout();
    }
    sessionChanges.value++;
  }

  Future<void> setAuth(String newToken, Map<String, dynamic> userJson) async {
    token = newToken;
    currentUser = UserModel.fromJson(userJson);
    MyAdsUpdatesService.instance.reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token!);
    await prefs.setString('auth_user', jsonEncode(userJson));
    await _persistLocation(_profileLocation());
    sessionChanges.value++;
  }

  Future<void> updateUser(Map<String, dynamic> userJson) async {
    currentUser = UserModel.fromJson(userJson);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_user', jsonEncode(userJson));
    await _persistLocation(_profileLocation());
  }

  MarketplaceLocation _profileLocation() {
    final user = currentUser;
    final city = user?.city?.trim();
    final fallback = MarketplaceLocation.forCity(
      city?.isNotEmpty == true ? city! : 'Kolkata',
    );
    return MarketplaceLocation(
      fallback.city,
      latitude: user?.latitude ?? fallback.latitude,
      longitude: user?.longitude ?? fallback.longitude,
      state: user?.state ?? fallback.state,
      country: user?.country ?? fallback.country,
    );
  }

  Future<void> _persistLocation(MarketplaceLocation selected) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('marketplace_city', selected.city);
    await prefs.setInt('marketplace_user_id', currentUserId);
    for (final entry in {
      'marketplace_latitude': selected.latitude,
      'marketplace_longitude': selected.longitude,
    }.entries) {
      if (entry.value == null) {
        await prefs.remove(entry.key);
      } else {
        await prefs.setDouble(entry.key, entry.value!);
      }
    }
    for (final entry in {
      'marketplace_state': selected.state,
      'marketplace_country': selected.country,
    }.entries) {
      if (entry.value == null) {
        await prefs.remove(entry.key);
      } else {
        await prefs.setString(entry.key, entry.value!);
      }
    }
    location.value = selected;
  }

  Future<void> restoreLocation({
    String fallbackCity = 'Kolkata',
    ApiService? api,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getInt('marketplace_user_id');
    final city = prefs.getString('marketplace_city');
    if (city?.trim().isNotEmpty == true &&
        (owner == null || owner == currentUserId)) {
      final fallback = MarketplaceLocation.forCity(city!);
      final selected = MarketplaceLocation(
        city,
        latitude: prefs.getDouble('marketplace_latitude') ?? fallback.latitude,
        longitude:
            prefs.getDouble('marketplace_longitude') ?? fallback.longitude,
        state: prefs.getString('marketplace_state') ?? fallback.state,
        country: prefs.getString('marketplace_country') ?? fallback.country,
      );
      await _persistLocation(selected);
      if (isAuthenticated &&
          (currentUser?.city != city ||
              currentUser?.latitude != selected.latitude ||
              currentUser?.longitude != selected.longitude)) {
        try {
          await selectLocation(selected, api: api);
        } catch (_) {
          // Keep the previously selected city usable while offline; retry on restore.
        }
      }
    } else {
      await _persistLocation(
        isAuthenticated
            ? _profileLocation()
            : MarketplaceLocation.forCity(fallbackCity),
      );
    }
  }

  Future<void> selectLocation(
    MarketplaceLocation selected, {
    ApiService? api,
  }) async {
    final session = token;
    if (isAuthenticated) {
      final result = await (api ?? ApiService()).updateLocation(selected);
      if (token != session) {
        throw Exception(
          'Your account changed. Please select your location again.',
        );
      }
      await updateUser(Map<String, dynamic>.from(result['user']));
    } else {
      await _persistLocation(selected);
    }
  }

  Future<void> logout() async {
    final oldSession = token;
    token = null;
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    MyAdsUpdatesService.instance.reset();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    for (final key in [
      'marketplace_city',
      'marketplace_user_id',
      'marketplace_latitude',
      'marketplace_longitude',
      'marketplace_state',
      'marketplace_country',
    ]) {
      await prefs.remove(key);
    }
    location.value = null;
    final cleanup = onLogout;
    if (cleanup != null) {
      // Persist the cleared session locally, but never keep the user waiting
      // for push deregistration or another network-dependent cleanup step.
      unawaited(
        Future<void>.sync(() => cleanup(oldSession)).catchError((Object _) {
          debugPrint(
            'Logout cleanup could not complete; local session is cleared.',
          );
        }),
      );
    }
    sessionChanges.value++;
  }
}
