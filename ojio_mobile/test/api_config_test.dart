import 'package:flutter_test/flutter_test.dart';
import 'package:ojio_mobile/core/api_config.dart';
import 'package:ojio_mobile/core/constants.dart' as palette;
import 'package:ojio_mobile/core/theme.dart' as theme;

void main() {
  test('API and media constants share the selected backend', () {
    expect(palette.AppConstants.baseApiUrl, ApiConfig.baseUrl);
    expect(palette.AppConstants.webBaseApiUrl, ApiConfig.baseUrl);
    expect(theme.AppConstants.baseApiUrl, ApiConfig.baseUrl);
    expect(theme.AppConstants.webBaseApiUrl, ApiConfig.baseUrl);
    expect(
      palette.AppConstants.storageBaseUrl,
      Uri.parse(ApiConfig.baseUrl).origin,
    );
  });

  test('relative images use the selected API origin, including its port', () {
    expect(
      ApiConfig.resolveMediaUrl('/storage/categories/car.png'),
      '${Uri.parse(ApiConfig.baseUrl).origin}/storage/categories/car.png',
    );
    expect(
      ApiConfig.resolveMediaUrl('storage/categories/car.png'),
      '${Uri.parse(ApiConfig.baseUrl).origin}/storage/categories/car.png',
    );
  });

  test('absolute CDN and embedded image URLs are preserved', () {
    expect(
      ApiConfig.resolveMediaUrl('https://cdn.example.com/image.jpg'),
      'https://cdn.example.com/image.jpg',
    );
    expect(
      ApiConfig.resolveMediaUrl('data:image/png;base64,aGVsbG8='),
      'data:image/png;base64,aGVsbG8=',
    );
  });
}
