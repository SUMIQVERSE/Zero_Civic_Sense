import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../models.dart';

class AutoReportServiceConfig {
  AutoReportServiceConfig({
    String? endpoint,
    this.authToken = const String.fromEnvironment(
      'CIVICSETU_AUTOREPORT_TOKEN',
      defaultValue: '',
    ),
    this.defaultReviewWindowSeconds = const int.fromEnvironment(
      'CIVICSETU_AUTOREPORT_REVIEW_SECONDS',
      defaultValue: 5,
    ),
  }) : endpoint = _resolveEndpoint(endpoint);

  final String endpoint;
  final String authToken;
  final int defaultReviewWindowSeconds;
}

const _configuredAutoReportEndpoint = String.fromEnvironment(
  'CIVICSETU_AUTOREPORT_ENDPOINT',
  defaultValue: '',
);

String _resolveEndpoint(String? explicitEndpoint) {
  if ((explicitEndpoint ?? '').trim().isNotEmpty) {
    return explicitEndpoint!.trim();
  }
  if (_configuredAutoReportEndpoint.trim().isNotEmpty) {
    return _configuredAutoReportEndpoint.trim();
  }
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:8787/v1/analyze-complaint-image';
  }
  return '';
}

class AutoReportException implements Exception {
  const AutoReportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AutoReportDraft {
  const AutoReportDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.isCivicIssue,
    required this.specificIssueType,
    required this.shouldUpdateCategory,
    required this.urgency,
    required this.confidence,
    required this.detectedObjects,
    required this.summary,
    required this.reasoning,
    required this.providerLabel,
    required this.needsManualReview,
    required this.autoSubmitRecommended,
    required this.reviewWindowSeconds,
  });

  final String title;
  final String description;
  final IssueCategory category;
  final bool isCivicIssue;
  final String specificIssueType;
  final bool shouldUpdateCategory;
  final UrgencyTag urgency;
  final double confidence;
  final List<String> detectedObjects;
  final String summary;
  final String reasoning;
  final String providerLabel;
  final bool needsManualReview;
  final bool autoSubmitRecommended;
  final int reviewWindowSeconds;
}

class AutoReportService {
  AutoReportService({
    AutoReportServiceConfig? config,
    this.client,
  }) : config = config ?? AutoReportServiceConfig();

  final AutoReportServiceConfig config;
  final http.Client? client;

  bool get isConfigured => config.endpoint.trim().isNotEmpty;

  static const int _maxInputBytes = 12 * 1024 * 1024;
  static const int _targetMaxDimension = 1440;
  static const int _targetEncodedBytes = 1 * 1024 * 1024;
  static const Duration _requestTimeout = Duration(seconds: 90);

  Future<AutoReportDraft> analyzeComplaintCapture({
    required String imagePath,
    required AppLanguage language,
    required AppUser user,
    LocationDraft? locationDraft,
  }) async {
    if (!isConfigured) {
      throw const AutoReportException(
        'AI auto-report backend is not configured for this build.',
      );
    }

    final file = File(imagePath);
    if (!file.existsSync()) {
      throw const AutoReportException('Selected image could not be found.');
    }

    final length = await file.length();
    if (length > _maxInputBytes) {
      throw const AutoReportException(
        'Image is too large for AI review. Capture a slightly smaller photo and try again.',
      );
    }

    final preparedImage = await _prepareImagePayload(file);
    final body = <String, Object?>{
      'imageBase64': base64Encode(preparedImage.bytes),
      'mimeType': preparedImage.mimeType,
      'language': language.code,
      'reviewWindowSeconds': config.defaultReviewWindowSeconds,
      'user': {
        'id': user.id,
        'role': user.role.key,
        'state': user.state,
        'city': user.city,
        'trustCode': user.trustCode,
      },
      'location': locationDraft == null
          ? null
          : {
              'latitude': locationDraft.latitude,
              'longitude': locationDraft.longitude,
              'state': locationDraft.state,
              'city': locationDraft.city,
              'address': locationDraft.address,
              'accuracyMeters': locationDraft.accuracyMeters,
            },
    };

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (config.authToken.trim().isNotEmpty)
        'Authorization': 'Bearer ${config.authToken.trim()}',
    };

    final activeClient = client ?? http.Client();
    try {
      final response = await activeClient
          .post(
            Uri.parse(config.endpoint),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message =
            (decoded['error'] ?? decoded['message'] ?? 'AI analysis failed.')
                .toString();
        throw AutoReportException(message);
      }

      final draft = AutoReportDraft(
        title: (decoded['title'] ?? '').toString().trim(),
        description: (decoded['description'] ?? '').toString().trim(),
        category: issueCategoryFromKey((decoded['category'] ?? '').toString()),
        isCivicIssue:
            decoded['isCivicIssue'] == true ||
            decoded['is_civic_issue'] == true,
        specificIssueType:
            (decoded['specificIssueType'] ??
                    decoded['specific_issue_type'] ??
                    'unclear_or_non_civic')
                .toString()
                .trim(),
        shouldUpdateCategory:
            decoded['shouldUpdateCategory'] == true ||
            decoded['should_update_category'] == true,
        urgency: urgencyTagFromKey((decoded['urgency'] ?? '').toString()),
        confidence: _parseConfidence(decoded['confidence']),
        detectedObjects: ((decoded['detectedObjects'] ??
                decoded['detected_objects'] ??
                const <Object?>[]) as List)
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList(),
        summary: (decoded['summary'] ?? '').toString().trim(),
        reasoning: (decoded['reasoning'] ?? '').toString().trim(),
        providerLabel: (decoded['providerLabel'] ??
                decoded['provider'] ??
                'AI auto-report')
            .toString()
            .trim(),
        needsManualReview: decoded['needsManualReview'] == true ||
            decoded['needs_manual_review'] == true,
        autoSubmitRecommended: decoded['autoSubmitRecommended'] == true ||
            decoded['auto_submit_recommended'] == true,
        reviewWindowSeconds: _parseSeconds(
          decoded['reviewWindowSeconds'] ?? decoded['review_window_seconds'],
          fallback: config.defaultReviewWindowSeconds,
        ),
      );
      if (draft.title.isEmpty || draft.description.isEmpty) {
        throw const AutoReportException(
          'AI response was incomplete. Please review manually and retry once.',
        );
      }
      return draft;
    } on FormatException {
      throw const AutoReportException(
        'AI response could not be understood. Please retry once.',
      );
    } on TimeoutException {
      throw const AutoReportException(
        'AI review is taking longer than expected. Please retry once with a clearer photo or submit manually.',
      );
    } on http.ClientException catch (error) {
      throw AutoReportException(error.message);
    } finally {
      if (client == null) {
        activeClient.close();
      }
    }
  }

  static String _mimeTypeFor(String imagePath) {
    final lower = imagePath.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    return 'image/jpeg';
  }

  static Future<_PreparedImagePayload> _prepareImagePayload(File file) async {
    final originalBytes = await file.readAsBytes();
    final fallbackMimeType = _mimeTypeFor(file.path);
    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      return _PreparedImagePayload(
        bytes: originalBytes,
        mimeType: fallbackMimeType,
      );
    }

    img.Image workingImage = decoded;
    final longestSide = math.max(decoded.width, decoded.height);
    if (longestSide > _targetMaxDimension) {
      final scale = _targetMaxDimension / longestSide;
      workingImage = img.copyResize(
        decoded,
        width: math.max(1, (decoded.width * scale).round()),
        height: math.max(1, (decoded.height * scale).round()),
        interpolation: img.Interpolation.average,
      );
    }

    var encoded = img.encodeJpg(workingImage, quality: 82);
    if (encoded.length > _targetEncodedBytes) {
      encoded = img.encodeJpg(workingImage, quality: 72);
    }

    if (encoded.length >= originalBytes.length &&
        originalBytes.length <= _targetEncodedBytes) {
      return _PreparedImagePayload(
        bytes: originalBytes,
        mimeType: fallbackMimeType,
      );
    }

    return _PreparedImagePayload(
      bytes: encoded,
      mimeType: 'image/jpeg',
    );
  }

  static double _parseConfidence(Object? value) {
    final parsed = switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text),
      _ => null,
    };
    return (parsed ?? 0.0).clamp(0.0, 1.0);
  }

  static int _parseSeconds(Object? value, {required int fallback}) {
    final parsed = switch (value) {
      num number => number.toInt(),
      String text => int.tryParse(text),
      _ => null,
    };
    final safeFallback = fallback < 0 ? 0 : fallback;
    return parsed == null || parsed < 0 ? safeFallback : parsed;
  }
}

class _PreparedImagePayload {
  const _PreparedImagePayload({
    required this.bytes,
    required this.mimeType,
  });

  final List<int> bytes;
  final String mimeType;
}
