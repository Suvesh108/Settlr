import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sms_detector.dart';

class SmsService {
  static const MethodChannel _channel = MethodChannel('com.settlr.sms');
  static final StreamController<DetectedSpend> _spendStream =
      StreamController<DetectedSpend>.broadcast();

  static Stream<DetectedSpend> get onSpendDetected => _spendStream.stream;
  static bool _isInitialized = false;
  static final Set<String> _processedHashes = {};

  /// Initialize native SMS listener and request runtime permission on startup.
  static Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Load previously processed SMS hashes to ensure zero duplicate loops across restarts
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('settlr_processed_sms_hashes') ?? [];
    _processedHashes.addAll(saved);

    // Listen to native real-time incoming SMS broadcasts
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final Map<dynamic, dynamic>? args = call.arguments;
        final body = args?['body'] as String?;
        final timestamp = args?['timestamp'] as int?;
        if (body != null && body.isNotEmpty) {
          _processSmsText(body, timestamp);
        }
      }
    });

    // Request SMS permission on startup
    try {
      final granted = await _channel.invokeMethod<bool>('requestSmsPermission');
      if (granted == true) {
        // Query only messages received in the last 2 minutes that have never been seen
        await checkRecentMessages();
      }
    } catch (_) {}
  }

  /// Queries only recent inbox messages (strictly < 120 seconds old)
  static Future<void> checkRecentMessages() async {
    try {
      final List<dynamic>? list =
          await _channel.invokeMethod<List<dynamic>>('getLatestSms');
      if (list != null && list.isNotEmpty) {
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final item in list) {
          if (item is Map) {
            final body = item['body'] as String?;
            final timestamp = (item['timestamp'] as num?)?.toInt() ?? (item['date'] as num?)?.toInt();

            // Strict time guard: ignore any SMS older than 2 minutes
            if (timestamp != null && (now - timestamp) > 120000) {
              continue;
            }

            if (body != null && body.isNotEmpty) {
              final spend = SmsSpendDetector.parseSms(body, timestamp);
              if (spend != null) {
                if (_processedHashes.contains(spend.deduplicationHash)) {
                  continue; // Already processed, ignore
                }

                _recordAndEmitSpend(spend);
                break; // Trigger only one active spend popup
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  static void _processSmsText(String body, [int? timestamp]) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Strict guard: if timestamp exists and is older than 2 minutes, ignore
    if (timestamp != null && (now - timestamp) > 120000) {
      return;
    }

    final spend = SmsSpendDetector.parseSms(body, timestamp);
    if (spend != null) {
      if (_processedHashes.contains(spend.deduplicationHash)) {
        return; // Already seen or popped up
      }

      _recordAndEmitSpend(spend);
    }
  }

  static Future<void> _recordAndEmitSpend(DetectedSpend spend) async {
    _processedHashes.add(spend.deduplicationHash);

    // Keep at most 200 hashes in persistent storage
    final prefs = await SharedPreferences.getInstance();
    final list = _processedHashes.toList();
    if (list.length > 200) {
      list.removeRange(0, list.length - 200);
    }
    await prefs.setStringList('settlr_processed_sms_hashes', list);

    _spendStream.add(spend);
  }

  /// Manually mark a spend as processed (e.g. dismissed by user)
  static Future<void> markSpendProcessed(String deduplicationHash) async {
    _processedHashes.add(deduplicationHash);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('settlr_processed_sms_hashes', _processedHashes.toList());
  }

  /// Manually parse text (e.g. from clipboard or testing)
  static DetectedSpend? parseText(String text) {
    return SmsSpendDetector.parseSms(text);
  }
}
