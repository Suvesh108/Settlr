import 'dart:async';
import 'package:flutter/services.dart';
import 'sms_detector.dart';

class SmsService {
  static const MethodChannel _channel = MethodChannel('com.settlr.sms');
  static final StreamController<DetectedSpend> _spendStream =
      StreamController<DetectedSpend>.broadcast();

  static Stream<DetectedSpend> get onSpendDetected => _spendStream.stream;
  static bool _isInitialized = false;

  /// Initialize native SMS listener and request runtime permission on startup.
  static Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Listen to native incoming SMS broadcasts
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final Map<dynamic, dynamic>? args = call.arguments;
        final body = args?['body'] as String?;
        if (body != null && body.isNotEmpty) {
          _processSmsText(body);
        }
      }
    });

    // Request SMS permission on startup
    try {
      final granted = await _channel.invokeMethod<bool>('requestSmsPermission');
      if (granted == true) {
        // Check latest SMS from inbox to catch any recent spends
        await checkRecentMessages();
      }
    } catch (_) {}
  }

  /// Queries the most recent messages in the inbox to detect recent bank spending
  static Future<void> checkRecentMessages() async {
    try {
      final List<dynamic>? list =
          await _channel.invokeMethod<List<dynamic>>('getLatestSms');
      if (list != null && list.isNotEmpty) {
        for (final item in list) {
          if (item is Map) {
            final body = item['body'] as String?;
            if (body != null && body.isNotEmpty) {
              final spend = SmsSpendDetector.parseSms(body);
              if (spend != null) {
                _spendStream.add(spend);
                break; // Trigger only the most recent debit
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  static void _processSmsText(String body) {
    final spend = SmsSpendDetector.parseSms(body);
    if (spend != null) {
      _spendStream.add(spend);
    }
  }

  /// Manually parse text (e.g. from clipboard or testing)
  static DetectedSpend? parseText(String text) {
    return SmsSpendDetector.parseSms(text);
  }
}
