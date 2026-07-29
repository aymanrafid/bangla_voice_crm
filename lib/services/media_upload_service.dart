import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config_service.dart';

class MediaUploadService {
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

    final response = await http.Response.fromStream(await request.send());
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['detail']?.toString() ?? 'Media upload failed.');
    }
    return data['public_url']?.toString() ?? data['url']?.toString() ?? '';
  }
}
