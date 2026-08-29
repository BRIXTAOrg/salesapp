import 'dart:convert';

import 'package:http/http.dart' as http;

import '../device/device_identity.dart';
import 'api_config.dart';

class FieldApi {
  // BRIXTA_JSON_RESPONSE_BUDGET_V1
  //
  // A mobile JSON endpoint should never be allowed to hand the
  // application an arbitrarily large response and then ask jsonDecode
  // to manufacture the complete object graph.
  //
  // 8 MiB is deliberately generous for application JSON while still
  // providing a hard memory/latency envelope.
  static const int maxJsonResponseBytes = 8388608;

  // BRIXTA_REQUEST_TIMEOUT_V1
  static const Duration defaultRequestTimeout = Duration(seconds: 20);

  FieldApi({
    required this.accessToken,
    http.Client? client,
    Duration requestTimeout = defaultRequestTimeout,
  }) : _client = client ?? http.Client(),
       _requestTimeout = requestTimeout;

  final String accessToken;
  final http.Client _client;
  final Duration _requestTimeout;

  Future<T> _bounded<T>(Future<T> operation) {
    return operation.timeout(
      _requestTimeout,
      onTimeout: () {
        throw const FieldApiException(
          'The server took too long to respond.',
          code: 'REQUEST_TIMEOUT',
          statusCode: 408,
        );
      },
    );
  }

  Map<String, String> get _headers => {
    'authorization': 'Bearer $accessToken',
    'content-type': 'application/json',
    ...AppDeviceIdentity.instance.requestHeaders,
  };

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _bounded(
      _client.get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _bounded(
      _client.post(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _bounded(
      _client.patch(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final request =
        http.Request('DELETE', Uri.parse('${ApiConfig.baseUrl}$path'))
          ..headers.addAll(_headers)
          ..body = jsonEncode(body ?? const <String, dynamic>{});

    final streamed = await _bounded(_client.send(request));

    final response = await _bounded(http.Response.fromStream(streamed));
    return _decode(response);
  }

  /// Uploads one generic Responsibility media primitive.
  ///
  /// The backend deliberately exposes one endpoint for photo/file/signature/
  /// audio evidence. Existing callers may keep using uploadPhoto().
  Future<Map<String, dynamic>> uploadMedia(String filePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/salesApp/media'),
    );
    request.headers['authorization'] = 'Bearer $accessToken';
    request.headers.addAll(AppDeviceIdentity.instance.requestHeaders);
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamed = await _bounded(request.send());

    final response = await _bounded(http.Response.fromStream(streamed));
    final body = _decode(response);
    final raw = body['media'];

    if (raw is! Map) {
      throw const FieldApiException(
        'Media upload succeeded but no media record was returned.',
      );
    }

    final media = Map<String, dynamic>.from(raw);
    final url = media['url']?.toString();
    if (url == null || url.isEmpty) {
      throw const FieldApiException(
        'Media upload succeeded but no URL was returned.',
      );
    }

    return media;
  }

  Future<String> uploadPhoto(String filePath) async {
    final media = await uploadMedia(filePath);
    return media['url'].toString();
  }

  Map<String, dynamic> _decode(http.Response response) {
    /*
     * Check bytes BEFORE jsonDecode().
     *
     * `response.bodyBytes` already exists inside http.Response;
     * this does not manufacture the decoded JSON object graph.
     */
    final responseBytes = response.bodyBytes.length;

    if (responseBytes > maxJsonResponseBytes) {
      throw FieldApiException(
        'Server response exceeded the mobile JSON safety limit.',
        code: 'RESPONSE_TOO_LARGE',
        details: {
          'responseBytes': responseBytes,
          'maxResponseBytes': maxJsonResponseBytes,
        },
        statusCode: response.statusCode,
      );
    }

    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        body = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] == false) {
      throw FieldApiException(
        (body['error'] ?? 'Request failed (${response.statusCode}).')
            .toString(),
        code: body['code']?.toString(),
        details: body['details'],
        statusCode: response.statusCode,
      );
    }

    return body;
  }
}

class FieldApiException implements Exception {
  const FieldApiException(
    this.message, {
    this.code,
    this.details,
    this.statusCode,
  });

  final String message;
  final String? code;
  final dynamic details;
  final int? statusCode;

  @override
  String toString() => message;
}
