import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

final backendClientProvider = Provider<BackendClient>((ref) {
  return BackendClient(baseUrl: resolveApiUrl());
});

class BackendClient {
  BackendClient({required String baseUrl}) : _baseUrl = baseUrl.trim();

  final String _baseUrl;

  bool get isConfigured => _baseUrl.isNotEmpty;

  Uri buildUri(String path) {
    if (_baseUrl.startsWith('/')) {
      return Uri.parse('${_baseUrl.replaceFirst(RegExp(r'/$'), '')}$path');
    }

    final normalizedBaseUrl = _normalizeHttpBaseUrl(_baseUrl);
    return Uri.parse('$normalizedBaseUrl$path');
  }

  String buildWebSocketUrl(String path) {
    if (_baseUrl.startsWith('/')) {
      throw const BackendClientException(
        'WebSocket is unavailable for relative demo API_URL.',
      );
    }

    final normalizedBaseUrl = _normalizeHttpBaseUrl(_baseUrl);
    return normalizedBaseUrl.startsWith('https://')
        ? 'wss://${normalizedBaseUrl.substring(8)}$path'
        : 'ws://${normalizedBaseUrl.substring(7)}$path';
  }

  Iterable<String>? buildAuthenticatedWebSocketProtocols() {
    final accessToken = _accessToken;
    if (accessToken == null) {
      return null;
    }
    return ['supabase-auth.$accessToken'];
  }

  Future<http.Response> postJson(
    String path, {
    required Map<String, dynamic> body,
  }) {
    return http.post(
      buildUri(path),
      headers: _jsonHeaders(),
      body: jsonEncode(body),
    );
  }

  String? get _accessToken {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _jsonHeaders() {
    final accessToken = _accessToken;
    return {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }

  Future<CallStartResult> startCall({
    required String userId,
    required String targetNumber,
    required String language,
    required String greetingText,
    required bool aiMediation,
    required String voicePreset,
  }) async {
    final response = await postJson(
      '/call',
      body: {
        'user_id': userId,
        'target_number': targetNumber,
        'language': language,
        'greeting_text': greetingText,
        'ai_mediation': aiMediation,
        'voice_preset': voicePreset,
      },
    );

    return CallStartResult.fromResponse(response);
  }

  Future<VoicePreviewAudio?> fetchVoicePreview({
    required String text,
    required String voice,
  }) async {
    final response = await postJson(
      '/preview-voice',
      body: {'text': text, 'voice_preset': voice},
    );
    if (response.statusCode == 200) {
      return VoicePreviewAudio(
        bytes: response.bodyBytes,
        mimeType: response.headers['content-type'] ?? 'audio/mpeg',
      );
    }
    final body = CallStartResult._tryDecodeJson(response.body);
    final message =
        body?['detail'] ?? body?['message'] ?? 'Voice preview failed.';
    throw BackendClientException(message.toString());
  }

  Future<void> prefetchGreeting({
    required String text,
    required String language,
    required String voice,
  }) async {
    await postJson(
      '/prefetch',
      body: {'text': text, 'language': language, 'voice_preset': voice},
    );
  }
}

class VoicePreviewAudio {
  const VoicePreviewAudio({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

class CallStartResult {
  CallStartResult({
    required this.statusCode,
    required this.status,
    this.callId,
    this.mode,
    this.message,
  });

  final int statusCode;
  final String? status;
  final String? callId;
  final String? mode;
  final String? message;

  bool get isSuccess =>
      statusCode == 200 && status == 'success' && callId != null;

  factory CallStartResult.fromResponse(http.Response response) {
    final Map<String, dynamic>? body = _tryDecodeJson(response.body);
    return CallStartResult(
      statusCode: response.statusCode,
      status: body?['status'] as String?,
      callId: body?['call_id'] as String?,
      mode: body?['mode'] as String?,
      message: body?['message'] as String?,
    );
  }

  static Map<String, dynamic>? _tryDecodeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }
}

String _normalizeHttpBaseUrl(String rawBaseUrl) {
  if (rawBaseUrl.isEmpty) {
    throw const BackendClientException(
      'API_URL missing. Check .env & pubspec.yaml',
    );
  }

  if (rawBaseUrl.startsWith('http://') || rawBaseUrl.startsWith('https://')) {
    return rawBaseUrl;
  }

  return 'https://$rawBaseUrl';
}

String resolveApiUrl() {
  const dartDefineApiUrl = String.fromEnvironment('API_URL');
  final envApiUrl = dotenv.env['API_URL'] ?? '';
  return dartDefineApiUrl.isNotEmpty ? dartDefineApiUrl : envApiUrl;
}

class BackendClientException implements Exception {
  const BackendClientException(this.message);

  final String message;

  @override
  String toString() => message;
}
