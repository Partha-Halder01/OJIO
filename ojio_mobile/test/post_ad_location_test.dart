import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:ojio_mobile/core/post_ad_location.dart';

void main() {
  test('a road is not presented as a neighbourhood', () {
    final location = postAdPlacemarkLocation([
      const Placemark(
        locality: 'Kolkata',
        subLocality: '  ',
        thoroughfare: 'Park Street',
      ),
    ]);
    expect(location?['city'], 'Kolkata');
    expect(location?['locality'], '');
  });
  test('another address result cannot supply a neighbouring area', () {
    final location = postAdPlacemarkLocation([
      const Placemark(locality: 'Kolkata', thoroughfare: 'Some road'),
      const Placemark(locality: 'Janwada', subLocality: ' Nearby village '),
    ]);
    expect(location?['city'], 'Kolkata');
    expect(location?['locality'], '');
    expect(location?['places'], isNot(contains('Janwada')));
  });
  test('city names are not presented as detected area names', () {
    expect(
      postAdPlacemarkLocation([
        const Placemark(locality: 'Kolkata', subLocality: 'Calcutta'),
      ])?['locality'],
      '',
    );
    expect(postAdPlacemarkLocation([]), isNull);
  });
  test('matching providers preserve the detected neighbourhood', () async {
    final native = postAdPlacemarkLocation([
      const Placemark(locality: 'Kolkata', subLocality: 'Salt Lake'),
    ]);
    final result = await completePostAdLocation(
      native,
      () async => {
        'city': 'Kolkata',
        'locality': 'Salt Lake',
        'places': ['Kolkata'],
      },
    );
    expect(result['locality'], 'Salt Lake');
  });
  test('conflicting area names are not silently accepted', () async {
    final native = postAdPlacemarkLocation([
      const Placemark(locality: 'Hyderabad', subLocality: 'Janwada'),
    ]);
    final result = await completePostAdLocation(
      native,
      () async => {
        'city': 'Hyderabad',
        'locality': 'Nallagandla',
        'places': ['Hyderabad'],
      },
    );
    expect(result['city'], 'Hyderabad');
    expect(result['locality'], '');
    expect(result['area_conflict'], isTrue);
  });
  test('fallback from another city cannot supply an area', () async {
    final result = await completePostAdLocation(
      postAdPlacemarkLocation([const Placemark(locality: 'Hyderabad')]),
      () async => {
        'city': 'Kolkata',
        'locality': 'Behala',
        'places': ['Kolkata'],
      },
    );
    expect(result['locality'], '');
    expect(result['places'], isNot(contains('Kolkata')));
  });
  test('GPS must be precise enough to distinguish neighbourhoods', () {
    expect(postAdGpsIsPrecise(20), isTrue);
    expect(postAdGpsIsPrecise(100), isTrue);
    for (final accuracy in [
      0.0,
      -1.0,
      101.0,
      2000.0,
      double.nan,
      double.infinity,
    ]) {
      expect(postAdGpsIsPrecise(accuracy), isFalse);
    }
  });
  test('missing area is completed without replacing native city', () async {
    final native = postAdPlacemarkLocation([
      const Placemark(locality: 'Kolkata'),
    ]);
    final result = await completePostAdLocation(
      native,
      () async => {
        'city': 'Calcutta',
        'locality': 'New Town',
        'places': ['Calcutta', 'New Town'],
      },
    );
    expect(result['city'], 'Kolkata');
    expect(result['locality'], 'New Town');
    expect(result['places'], containsAll(['Kolkata', 'New Town']));
  });
  test('optional reverse lookup failure keeps detected city usable', () async {
    final native = postAdPlacemarkLocation([
      const Placemark(locality: 'Kolkata'),
    ]);
    final result = await completePostAdLocation(
      native,
      () async => throw Exception('Offline'),
    );
    expect(result['city'], 'Kolkata');
    expect(result['locality'], '');
  });
  test(
    'reverse lookup supplies both city and area when native is unavailable',
    () async {
      final result = await completePostAdLocation(
        null,
        () async => {
          'city': 'Kolkata',
          'locality': 'Behala',
          'places': ['Kolkata'],
        },
      );
      expect(result['locality'], 'Behala');
    },
  );
  test('backend city-only result is not mistaken for a locality', () async {
    final native = postAdPlacemarkLocation([
      const Placemark(locality: 'Kolkata'),
    ]);
    final result = await completePostAdLocation(
      native,
      () async => {
        'city': 'Kolkata',
        'locality': 'Kolkata',
        'places': ['Kolkata'],
      },
    );
    expect(result['locality'], '');
  });
}
