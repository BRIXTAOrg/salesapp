import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';

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

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {}

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] == false) {
      throw FieldApiException(
        (body['error'] ?? 'Request failed (${response.statusCode}).').toString(),
      );
    }

    return body;
  }
}

class FieldApiException implements Exception {
  const FieldApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
