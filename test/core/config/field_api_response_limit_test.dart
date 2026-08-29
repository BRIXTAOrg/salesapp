import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:salesapp/core/config/field_api.dart';

void main() {
  test('FieldApi accepts normal JSON responses', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"success":true,"value":42}',
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    final api = FieldApi(accessToken: 'qa', client: client);

    final response = await api.getJson('/qa');

    expect(response['value'], 42);
  });

  test('FieldApi rejects oversized JSON before jsonDecode', () async {
    /*
       * The body does not need to be valid JSON.
       *
       * That is intentional:
       * size rejection must happen BEFORE parsing is attempted.
       */
    final oversized = 'X' * (FieldApi.maxJsonResponseBytes + 1);

    final client = MockClient(
      (_) async => http.Response(
        oversized,
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    final api = FieldApi(accessToken: 'qa', client: client);

    await expectLater(
      api.getJson('/qa/oversized'),
      throwsA(
        isA<FieldApiException>().having(
          (error) => error.code,
          'code',
          'RESPONSE_TOO_LARGE',
        ),
      ),
    );
  });
}
