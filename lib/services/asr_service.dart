import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config_service.dart';

class AsrResult {
  final String text;
  final String debug;
  final String? error;

  AsrResult({required this.text, required this.debug, this.error});
}

class AsrJobStatus {
  final String jobId;
  final String status;
  final int progress;
  final String stage;
  final String message;
  final String text;
  final String debug;
  final String error;
  final int chunkCount;
  final int completedChunks;

  const AsrJobStatus({
    required this.jobId,
    required this.status,
    required this.progress,
    required this.stage,
    required this.message,
    required this.text,
    required this.debug,
    required this.error,
    required this.chunkCount,
    required this.completedChunks,
  });

  bool get isFinished => status == 'completed' || status == 'failed';

  factory AsrJobStatus.fromJson(Map<String, dynamic> json) {
    return AsrJobStatus(
      jobId: json['job_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      progress: int.tryParse(json['progress']?.toString() ?? '0') ?? 0,
      stage: json['stage']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      debug: json['debug']?.toString() ?? '',
      error: json['error']?.toString() ?? '',
      chunkCount: int.tryParse(json['chunk_count']?.toString() ?? '0') ?? 0,
      completedChunks:
          int.tryParse(json['completed_chunks']?.toString() ?? '0') ?? 0,
    );
  }
}

class AsrService {
  static final ApiConfigService _config = ApiConfigService();
  static const Duration _uploadTimeout = Duration(seconds: 60);
  static const Duration _pollTimeout = Duration(seconds: 20);
  static const Duration _overallTimeout = Duration(minutes: 30);
  static const Duration _pollInterval = Duration(seconds: 2);

  static Future<AsrResult> transcribe(
    String audioPath, {
    void Function(AsrJobStatus status)? onProgress,
  }) async {
    try {
      final apiUrl = await _config.getAsrApiUrl();

      if (apiUrl.isEmpty) {
        return AsrResult(
          text: '',
          debug: 'No API URL set',
          error:
              'No BanglaASR server URL is set. Go to Settings and paste your /transcribe URL.',
        );
      }

      final file = File(audioPath);
      if (!await file.exists()) {
        return AsrResult(
          text: '',
          debug: 'File not found',
          error: 'Audio file not found.',
        );
      }

      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes < 1000) {
        return AsrResult(
          text: '',
          debug: 'Too small',
          error: 'Recording is too short. Please speak for at least 2 seconds.',
        );
      }

      final submitUri = _jobSubmitUri(apiUrl);
      final request = http.MultipartRequest('POST', submitUri);
      request.files.add(
        http.MultipartFile.fromBytes(
          'audio',
          bytes,
          filename: file.uri.pathSegments.isNotEmpty
              ? file.uri.pathSegments.last
              : 'recording.wav',
        ),
      );

      final streamedResponse = await request.send().timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        return AsrResult(
          text: '',
          debug: 'HTTP ${response.statusCode}',
          error: _serverErrorMessage(
            response.statusCode,
            response.body,
            fallback:
                'Server error (${response.statusCode}). Check whether your BanglaASR backend is running.',
          ),
        );
      }

      final submitJson = jsonDecode(response.body) as Map<String, dynamic>;
      final initialStatus = AsrJobStatus.fromJson(submitJson);
      if (initialStatus.jobId.isEmpty) {
        return AsrResult(
          text: '',
          debug: 'Invalid job response',
          error: 'ASR server returned an invalid job response.',
        );
      }
      onProgress?.call(initialStatus);

      final deadline = DateTime.now().add(_overallTimeout);
      AsrJobStatus latest = initialStatus;
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(_pollInterval);
        final statusResponse = await http
            .get(_jobStatusUri(apiUrl, latest.jobId))
            .timeout(_pollTimeout);

        if (statusResponse.statusCode != 200) {
          return AsrResult(
            text: '',
            debug: 'HTTP ${statusResponse.statusCode}',
            error: _serverErrorMessage(
              statusResponse.statusCode,
              statusResponse.body,
              fallback: 'Failed to fetch ASR progress from the server.',
            ),
          );
        }

        latest = AsrJobStatus.fromJson(
          jsonDecode(statusResponse.body) as Map<String, dynamic>,
        );
        onProgress?.call(latest);

        if (latest.status == 'completed') {
          return AsrResult(
            text: latest.text,
            debug: latest.debug.isNotEmpty ? latest.debug : 'OK',
            error: latest.error.isEmpty ? null : latest.error,
          );
        }
        if (latest.status == 'failed') {
          return AsrResult(
            text: '',
            debug: latest.debug.isNotEmpty ? latest.debug : latest.message,
            error: latest.error.isNotEmpty ? latest.error : latest.message,
          );
        }
      }

      return AsrResult(
        text: '',
        debug: 'Timeout after ${_overallTimeout.inMinutes} minutes',
        error:
            'ASR processing took too long. Please try again or use a shorter audio file.',
      );
    } on SocketException {
      return AsrResult(
        text: '',
        debug: 'Network error',
        error:
            'Cannot reach the BanglaASR server. Make sure your phone and server are on the same network and the backend is running.',
      );
    } on TimeoutException catch (exc) {
      final reason = exc.duration == _uploadTimeout
          ? 'Upload timed out while submitting the audio.'
          : 'ASR progress request timed out.';
      return AsrResult(
        text: '',
        debug: 'Timeout: $reason',
        error: '$reason Please check server performance and try again.',
      );
    } catch (e) {
      return AsrResult(
        text: '',
        debug: 'Error: $e',
        error: 'Failed: $e',
      );
    }
  }

  static Uri _jobSubmitUri(String apiUrl) {
    final base = _normalizeBase(apiUrl);
    return Uri.parse('$base/transcribe-jobs');
  }

  static Uri _jobStatusUri(String apiUrl, String jobId) {
    final base = _normalizeBase(apiUrl);
    return Uri.parse('$base/transcribe-jobs/$jobId');
  }

  static String _normalizeBase(String apiUrl) {
    final trimmed = apiUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return trimmed.replaceFirst(RegExp(r'/transcribe$'), '');
  }

  static String _serverErrorMessage(
    int statusCode,
    String body, {
    required String fallback,
  }) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final detail = data['detail']?.toString();
        if (detail != null && detail.isNotEmpty) {
          return detail;
        }
        final error = data['error']?.toString();
        if (error != null && error.isNotEmpty) {
          return error;
        }
      }
    } catch (_) {
      // Ignore JSON parsing errors and return fallback below.
    }
    return fallback;
  }
}
