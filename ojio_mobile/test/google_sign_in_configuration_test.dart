import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ojio_mobile/core/google_sign_in_errors.dart';
import 'package:ojio_mobile/widgets/google_auth_button.dart';

void main() {
  test('app Web client matches the current Firebase project', () {
    final config =
        jsonDecode(File('android/app/google-services.json').readAsStringSync())
            as Map<String, dynamic>;
    final client = (config['client'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere(
          (client) =>
              client['client_info']['android_client_info']['package_name'] ==
              'com.ojio.app.ojio_mobile',
        );
    final oauth = (client['oauth_client'] as List).cast<Map<String, dynamic>>();
    expect(
      oauth.singleWhere((entry) => entry['client_type'] == 3)['client_id'],
      googleClientId,
    );
    expect(
      googleClientId,
      startsWith('${config['project_info']['project_number']}-'),
    );
    expect(File('web/index.html').readAsStringSync(), contains(googleClientId));
  });

  test('Google failures do not expose raw plugin exceptions', () {
    for (final details in ['12500', '10', 'unknown status']) {
      final message = googleSignInErrorMessage(
        PlatformException(
          code: 'sign_in_failed',
          message: 'com.google.android.gms.common.api.ApiException: $details',
        ),
      )!;
      expect(message, contains('email and password'));
      expect(message, isNot(contains('PlatformException')));
      expect(message, isNot(contains('ApiException')));
    }
    expect(
      googleSignInErrorMessage(
        const FormatException('secret diagnostic detail'),
      ),
      isNot(contains('secret')),
    );
  });

  test(
    'cancelled account picker is silent and network errors are actionable',
    () {
      expect(
        googleSignInErrorMessage(PlatformException(code: 'sign_in_canceled')),
        isNull,
      );
      expect(
        googleSignInErrorMessage(PlatformException(code: 'network_error')),
        contains('internet'),
      );
    },
  );
}
