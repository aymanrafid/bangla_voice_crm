import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import '../models/company_profile.dart';

class RemoteAuthSession {
  final String accessToken;
  final AppUser user;

  const RemoteAuthSession({
    required this.accessToken,
    required this.user,
  });
}

class RemoteAuthService {
  static const Duration _requestTimeout = Duration(seconds: 15);

  Uri _uri(String baseUrl, String path) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');

  Future<RemoteAuthSession> login({
    required String baseUrl,
    required String username,
    required String password,
    String? companySlug,
  }) async {
    late final http.Response response;
    try {
      response = await http
          .post(
            _uri(baseUrl, '/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username.trim(),
              'password': password,
              if (companySlug != null && companySlug.trim().isNotEmpty)
                'company_slug': companySlug.trim(),
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(
        'CRM login timed out. Check that the server URL is correct and reachable.',
      );
    }

    if (response.statusCode != 200) {
      final message = _extractError(response.body) ?? 'Login failed.';
      throw Exception(message);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final userMap = data['user'] as Map<String, dynamic>? ?? {};
    return RemoteAuthSession(
      accessToken: data['access_token']?.toString() ?? '',
      user: AppUser.fromApiMap(userMap),
    );
  }

  Future<AppUser> me({
    required String baseUrl,
    required String accessToken,
  }) async {
    late final http.Response response;
    try {
      response = await http.get(
        _uri(baseUrl, '/auth/me'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(
        'CRM session check timed out. The app will fall back to login.',
      );
    }

    if (response.statusCode != 200) {
      final message =
          _extractError(response.body) ?? 'Session validation failed.';
      throw Exception(message);
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AppUser.fromApiMap(data);
  }

  Future<AppUser> createUser({
    required String baseUrl,
    required String accessToken,
    required String username,
    required String password,
    required String fullName,
    required String role,
    String? companyExternalId,
  }) async {
    late final http.Response response;
    try {
      response = await http
          .post(
            _uri(baseUrl, '/auth/users'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'username': username.trim(),
              'password': password,
              'full_name': fullName.trim(),
              'role': role,
              'is_active': true,
              if (companyExternalId != null && companyExternalId.isNotEmpty)
                'company_external_id': companyExternalId,
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception('User creation timed out. Please try again.');
    }

    if (response.statusCode != 200) {
      final message = _extractError(response.body) ?? 'User creation failed.';
      throw Exception(message);
    }
    return AppUser.fromApiMap(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<AppUser>> getUsers({
    required String baseUrl,
    required String accessToken,
  }) async {
    late final http.Response response;
    try {
      response = await http.get(
        _uri(baseUrl, '/users'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception('Loading users timed out. Please try again.');
    }

    if (response.statusCode != 200) {
      final message = _extractError(response.body) ?? 'Failed to load users.';
      throw Exception(message);
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => AppUser.fromApiMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<CompanyProfile>> getCompanies({
    required String baseUrl,
    required String accessToken,
  }) async {
    late final http.Response response;
    try {
      response = await http.get(
        _uri(baseUrl, '/companies'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception('Loading companies timed out. Please try again.');
    }

    if (response.statusCode != 200) {
      final message =
          _extractError(response.body) ?? 'Failed to load companies.';
      throw Exception(message);
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => CompanyProfile.fromApiMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<CompanyProvisionResult> createCompany({
    required String baseUrl,
    required String accessToken,
    required String name,
    required String slug,
    required String adminUsername,
    required String adminPassword,
    required String adminFullName,
  }) async {
    late final http.Response response;
    try {
      response = await http
          .post(
            _uri(baseUrl, '/companies'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'name': name.trim(),
              'slug': slug.trim().isEmpty ? null : slug.trim(),
              'admin_username': adminUsername.trim(),
              'admin_password': adminPassword,
              'admin_full_name': adminFullName.trim(),
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception('Company creation timed out. Please try again.');
    }

    if (response.statusCode != 200) {
      final message =
          _extractError(response.body) ?? 'Company creation failed.';
      throw Exception(message);
    }
    return CompanyProvisionResult.fromApiMap(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  String? _extractError(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        return data['detail']?.toString();
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
