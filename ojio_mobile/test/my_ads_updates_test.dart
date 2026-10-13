import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ojio_mobile/models/models.dart';
import 'package:ojio_mobile/services/api_service.dart';
import 'package:ojio_mobile/services/auth_service.dart';
import 'package:ojio_mobile/services/my_ads_updates_service.dart';

void main() {
  setUp(() {
    AuthService().token = 'seller-token';
    AuthService().currentUser = UserModel.fromJson({'id': 1, 'name': 'Seller'});
  });
  tearDown(() {
    AuthService().token = null;
    AuthService().currentUser = null;
  });

  test('loads listing snapshot and acknowledges its exact revision', () async {
    final api = ApiService(
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer seller-token');
        if (request.method == 'POST') {
          expect(jsonDecode(request.body), {
            'updates': [
              {'id': 7, 'version': 2},
            ],
          });
          return http.Response('{"status":"success","has_updates":false}', 200);
        }
        return http.Response(
          '{"status":"success","data":[{"id":7,"admin_update_version":2}]}',
          200,
        );
      }),
    );
    final snapshot = await api.fetchMyAdsSnapshot();
    expect(snapshot['data'][0]['admin_update_version'], 2);
    expect(
      await api.readAdUpdates([
        {'id': 7, 'version': 2},
      ]),
      false,
    );
  });

  test(
    'failed reads preserve dot; successful acknowledgement clears it',
    () async {
      var fail = false;
      final service = MyAdsUpdatesService(
        api: ApiService(
          client: MockClient((request) async {
            if (fail) return http.Response('{"message":"Unavailable"}', 503);
            return http.Response(
              jsonEncode({
                'status': 'success',
                'has_updates': request.method == 'GET',
              }),
              200,
            );
          }),
        ),
      );
      await service.refresh();
      expect(service.value, true);
      fail = true;
      await service.acknowledge([
        {'id': 7, 'version': 2},
      ], AuthService().token);
      expect(service.value, true);
      await service.refresh();
      expect(service.value, true);
      fail = false;
      await service.acknowledge([
        {'id': 7, 'version': 2},
      ], AuthService().token);
      expect(service.value, false);
      service.dispose();
    },
  );

  test('older poll cannot restore a dot after acknowledgement', () async {
    final pending = Completer<http.Response>();
    final service = MyAdsUpdatesService(
      api: ApiService(
        client: MockClient((request) async {
          if (request.method == 'GET') return pending.future;
          return http.Response('{"status":"success","has_updates":false}', 200);
        }),
      ),
    );
    final poll = service.refresh();
    await service.acknowledge([
      {'id': 7, 'version': 2},
    ], AuthService().token);
    pending.complete(
      http.Response('{"status":"success","has_updates":true}', 200),
    );
    await poll;
    expect(service.value, false);
    service.dispose();
  });

  test('switching accounts ignores the previous account response', () async {
    final pending = Completer<http.Response>();
    final service = MyAdsUpdatesService(
      api: ApiService(client: MockClient((_) => pending.future)),
    );
    final poll = service.refresh();
    AuthService().token = 'other-user';
    pending.complete(
      http.Response('{"status":"success","has_updates":true}', 200),
    );
    await poll;
    expect(service.value, false);
    service.dispose();
  });

  test(
    'failed listing loads throw instead of acknowledging an empty list',
    () async {
      final api = ApiService(
        client: MockClient(
          (_) async => http.Response('{"message":"Unavailable"}', 503),
        ),
      );
      await expectLater(api.fetchMyAdsSnapshot(), throwsA(isA<ApiException>()));
    },
  );
}
