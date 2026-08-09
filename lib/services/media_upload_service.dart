import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config_service.dart';

class MediaUploadService {
  // Uploads carry a file body and may also hit a cold Render instance, so this
  // is more generous than the plain JSON calls in CrmApiClient.
  static const Duration _uploadTimeout = Duration(seconds: 90);

  final ApiConfigService _config = ApiConfigService();

  Future<bool> isConfigured() async {
    final baseUrl = await _config.getCrmApiBaseUrl();
    final token = await _config.getAccessToken();
    return baseUrl.isNotEmpty && token.isNotEmpty;
  }

  Future<String> uploadFile({
    required String filePath,
    required String category,
    String relatedType = 'general',
    String relatedExternalId = '',
  }) async {
    final baseUrl =
        (await _config.getCrmApiBaseUrl()).replaceAll(RegExp(r'/$'), '');
    final token = await _config.getAccessToken();
    if (baseUrl.isEmpty || token.isEmpty) {
      throw Exception('CRM media upload is not configured.');
    }
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Media file not found: $filePath');
    }

    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/media/upload'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['category'] = category;
    request.fields['related_type'] = relatedType;
    request.fields['related_external_id'] = relatedExternalId;
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    late final http.Response response;
    try {
      final streamed = await request.send().timeout(_uploadTimeout);
      response =
          await http.Response.fromStream(streamed).timeout(_uploadTimeout);
    } on TimeoutException {
      throw Exception(
        'Media upload timed out. The server may be waking up — '
        'the file stays queued, please retry.',
      );
    }

    // Decode after the status check: a booting Render instance answers with an
    // HTML error page, which would otherwise blow up as a FormatException and
    // hide the real failure.
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final failure = _tryDecodeJson(response.body);
      throw Exception(
        failure?['detail']?.toString() ??
            'Media upload failed (${response.statusCode}).',
      );
    }
    final data = _tryDecodeJson(response.body) ?? const <String, dynamic>{};
    return data['public_url']?.toString() ?? data['url']?.toString() ?? '';
  }

  Map<String, dynamic>? _tryDecodeJson(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
