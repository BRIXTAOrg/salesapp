import 'dart:convert';

import 'package:http/http.dart' as http;

import '../device/device_identity.dart';
import 'api_config.dart';

class FieldApi {
  FieldApi({
    required this.accessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String accessToken;
  final http.Client _client;

  Map<String, String> get _headers => {
        'authorization': 'Bearer $accessToken',
        'content-type': 'application/json',
        ...AppDeviceIdentity.instance.requestHeaders,
      };

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers,
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.patch(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final request = http.Request(
      'DELETE',
      Uri.parse('${ApiConfig.baseUrl}$path'),
    )
      ..headers.addAll(_headers)
      ..body = jsonEncode(body ?? const <String, dynamic>{});

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
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
    request.files.add(
      await http.MultipartFile.fromPath('file', filePath),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
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
        (body['error'] ?? 'Request failed (${response.statusCode}).').toString(),
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
