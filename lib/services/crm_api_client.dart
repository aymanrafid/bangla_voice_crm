import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config_service.dart';

class CrmApiClient {
  // Render's free plan sleeps after inactivity and a cold start takes 30-60 s.
  // Without an explicit timeout these calls hang until the OS TCP timeout, so
  // the UI sits on a spinner that never resolves and never shows an error.
  static const Duration _requestTimeout = Duration(seconds: 20);
  static const Duration _coldStartTimeout = Duration(seconds: 60);

  static const String _wakingUpMessage =
      'Server is waking up — please wait a moment and try again. '
      '(Render free tier goes to sleep after inactivity.)';

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

  /// One attempt on the full cold-start budget. Used for writes, which are not
  /// safe to replay: a timed-out POST may already have been applied server-side.
  Future<http.Response> _sendOnce(
    Future<http.Response> Function() send,
  ) async {
    try {
      return await send().timeout(_coldStartTimeout);
    } on TimeoutException {
      throw Exception(_wakingUpMessage);
    }
  }

  /// Short attempt, then one retry on the longer budget. Safe only for reads:
  /// the first call wakes a sleeping server so the retry usually succeeds.
  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() send,
  ) async {
    try {
      return await send().timeout(_requestTimeout);
    } on TimeoutException {
      return _sendOnce(send);
    }
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final baseUrl = await _baseUrl();
    final headers = await _headers(json: false);
    final uri = _uri(baseUrl, path, query);
    final response = await _sendWithRetry(() => http.get(uri, headers: headers));
    return _decodeResponse(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final baseUrl = await _baseUrl();
    final headers = await _headers();
    final uri = _uri(baseUrl, path);
    final payload = jsonEncode(body);
    final response =
        await _sendOnce(() => http.post(uri, headers: headers, body: payload));
    return _decodeResponse(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final baseUrl = await _baseUrl();
    final headers = await _headers();
    final uri = _uri(baseUrl, path);
    final payload = jsonEncode(body);
    final response =
        await _sendOnce(() => http.put(uri, headers: headers, body: payload));
    return _decodeResponse(response);
  }

  Future<dynamic> delete(String path) async {
    final baseUrl = await _baseUrl();
    final headers = await _headers(json: false);
    final uri = _uri(baseUrl, path);
    final response = await _sendOnce(() => http.delete(uri, headers: headers));
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
    // Render answers with an HTML error page for both a booting service and a
    // suspended one, and those need very different responses from the user.
    if (response.statusCode == 502 || response.statusCode == 503) {
      if (body.toLowerCase().contains('suspended')) {
        throw Exception(
          'This server is suspended on Render. Check the CRM API URL in '
          'Settings — it may still point at an old service.',
        );
      }
      throw Exception(_wakingUpMessage);
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
