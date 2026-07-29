import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config_service.dart';

class CrmApiClient {
  final ApiConfigService _config = ApiConfigService();

  Future<bool> isConfigured() async {
    final baseUrl = await _config.getCrmApiBaseUrl();
    final token = await _config.getAccessToken();
    return baseUrl.isNotEmpty && token.isNotEmpty;
  }

  Future<String> _baseUrl() async {
    final baseUrl = await _config.getCrmApiBaseUrl();
    if (baseUrl.isEmpty) {
      throw Exception('CRM API base URL is not configured.');
    }
    return baseUrl.replaceAll(RegExp(r'/$'), '');
  }

  Future<String> _token() async {
    final token = await _config.getAccessToken();
    if (token.isEmpty) {
      throw Exception('CRM access token is missing. Please log in again.');
    }
    return token;
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await _token();
    return {
      if (json) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String baseUrl, String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final baseUrl = await _baseUrl();
    final response = await http.get(
      _uri(baseUrl, path, query),
      headers: await _headers(json: false),
    );
    return _decodeResponse(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final baseUrl = await _baseUrl();
    final response = await http.post(
      _uri(baseUrl, path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final baseUrl = await _baseUrl();
    final response = await http.put(
      _uri(baseUrl, path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<dynamic> delete(String path) async {
    final baseUrl = await _baseUrl();
    final response = await http.delete(
      _uri(baseUrl, path),
      headers: await _headers(json: false),
    );
    return _decodeResponse(response);
  }

  dynamic _decodeResponse(http.Response response) {
    final body = response.body.trim();
    final decoded = _tryDecodeJson(body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail']?.toString();
      if (detail != null && detail.isNotEmpty) {
        throw Exception(detail);
      }
      final error = decoded['error']?.toString();
      if (error != null && error.isNotEmpty) {
        throw Exception(error);
      }
    }
    if (body.isNotEmpty) {
      throw Exception('CRM API error (${response.statusCode}): $body');
    }
    throw Exception('CRM API error (${response.statusCode}).');
  }

  dynamic _tryDecodeJson(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
