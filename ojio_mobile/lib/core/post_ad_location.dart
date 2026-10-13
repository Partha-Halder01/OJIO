import 'package:geocoding/geocoding.dart';
import 'marketplace_fields.dart';

bool postAdGpsIsPrecise(double accuracyMeters) =>
    accuracyMeters.isFinite && accuracyMeters > 0 && accuracyMeters <= 100;

Map<String, dynamic>? postAdPlacemarkLocation(List<Placemark> placemarks) {
  String firstValue(Iterable<String?> values, {String? excludingCity}) =>
      values
          .whereType<String>()
          .map((value) => value.trim())
          .where(
            (value) =>
                value.isNotEmpty &&
                (excludingCity == null ||
                    !MarketplaceFields.samePlace(value, excludingCity)),
          )
          .firstOrNull ??
      '';
  if (placemarks.isEmpty) return null;
  // Keep one coherent address; later results may describe a nearby village.
  final place = placemarks.first;
  final city = firstValue([
    place.locality,
    place.subAdministrativeArea,
    place.administrativeArea,
  ]);
  if (city.isEmpty) return null;
  return {
    'city': city,
    'locality': firstValue([place.subLocality], excludingCity: city),
    'places': {
      city,
      place.subAdministrativeArea?.trim() ?? '',
      place.administrativeArea?.trim() ?? '',
    }.where((value) => value.isNotEmpty).toList(),
  };
}

Future<Map<String, dynamic>> completePostAdLocation(
  Map<String, dynamic>? native,
  Future<Map<String, dynamic>> Function() reverseLookup,
) async {
  if (native == null) return reverseLookup();
  try {
    final fallback = await reverseLookup();
    final area = fallback['locality']?.toString().trim() ?? '';
    final nativeArea = native['locality']?.toString().trim() ?? '';
    final nativeCity = native['city'].toString();
    final sameCity =
        MarketplaceFields.samePlace(
          nativeCity,
          fallback['city']?.toString() ?? '',
        ) ||
        (native['places'] as List? ?? []).any(
          (place) => MarketplaceFields.samePlace(
            place.toString(),
            fallback['city']?.toString() ?? '',
          ),
        );
    final conflictingArea =
        nativeArea.isNotEmpty &&
        area.isNotEmpty &&
        (!sameCity || !MarketplaceFields.samePlace(nativeArea, area));
    return {
      ...native,
      'locality': conflictingArea
          ? ''
          : nativeArea.isNotEmpty
          ? nativeArea
          : (sameCity && !MarketplaceFields.samePlace(area, nativeCity)
                ? area
                : ''),
      'area_conflict': conflictingArea,
      'places': {
        ...?native['places'] as List?,
        if (sameCity) ...?fallback['places'] as List?,
      }.toList(),
    };
  } catch (_) {
    // Keep the detected city usable when the optional area lookup is offline.
    return native;
  }
}
