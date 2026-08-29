import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:salesapp/core/config/field_api.dart';

void main() {
  test('FieldApi accepts normal JSON responses', () async {
    final client = MockClient(
      (_) async => http.Response('{"success":true,"value":42}', 200),
    );

    final api = FieldApi(accessToken: 'qa', client: client);

    final response = await api.getJson('/qa');

    expect(response['value'], 42);
  });

  test('oversized responses die before jsonDecode', () async {
    final oversized = 'X' * (FieldApi.maxJsonResponseBytes + 1);

    final client = MockClient((_) async => http.Response(oversized, 200));

    final api = FieldApi(accessToken: 'qa', client: client);

    await expectLater(
      api.getJson('/qa/large'),
      throwsA(
        isA<FieldApiException>().having(
          (e) => e.code,
          'code',
          'RESPONSE_TOO_LARGE',
        ),
      ),
    );
  });

  test('stalled HTTP request is killed at timeout', () async {
    final client = MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));

      return http.Response('{"success":true}', 200);
    });

    final api = FieldApi(
      accessToken: 'qa',
      client: client,
      requestTimeout: const Duration(milliseconds: 25),
    );

    final stopwatch = Stopwatch()..start();

    await expectLater(
      api.getJson('/qa/stall'),
      throwsA(
        isA<FieldApiException>().having(
          (e) => e.code,
          'code',
          'REQUEST_TIMEOUT',
        ),
      ),
    );

    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, lessThan(150));
  });
}
