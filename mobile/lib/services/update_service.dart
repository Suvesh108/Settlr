import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String? downloadUrl;
  final int? size;
  final String? releaseNotes;

  UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    this.downloadUrl,
    this.size,
    this.releaseNotes,
  });
}

class UpdateService {
  static const String currentVersion = 'v0.0.6';
  static const String repoOwner = 'Suvesh108';
  static const String repoName = 'Settlr';
  static const MethodChannel _platform = MethodChannel('com.settlr.updater');

  /// Queries GitHub Releases API for the latest release
  static Future<UpdateInfo> checkForUpdate() async {
    final url = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'Settlr-Android-App',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to check for updates (HTTP ${response.statusCode})');
    }

    final data = jsonDecode(response.body);
    final String tagName = (data['tag_name'] as String?)?.trim() ?? '';
    final String body = (data['body'] as String?) ?? '';
    final List<dynamic> assets = data['assets'] ?? [];

    String? apkDownloadUrl;
    int? apkSize;

    for (final asset in assets) {
      final name = (asset['name'] as String?)?.toLowerCase() ?? '';
      if (name.endsWith('.apk')) {
        apkDownloadUrl = asset['browser_download_url'] as String?;
        apkSize = asset['size'] as int?;
        break;
      }
    }

    // Compare semantic tags, e.g. v0.0.2 vs v0.0.1
    final isNewer = _isVersionNewer(tagName, currentVersion);

    return UpdateInfo(
      hasUpdate: isNewer && apkDownloadUrl != null,
      currentVersion: currentVersion,
      latestVersion: tagName.isNotEmpty ? tagName : currentVersion,
      downloadUrl: apkDownloadUrl,
      size: apkSize,
      releaseNotes: body,
    );
  }

  /// Downloads the APK directly inside the app with live progress, then invokes system installer
  static Future<void> downloadAndInstall({
    required String downloadUrl,
    required Function(double progress, int received, int total) onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final apkFile = File('${tempDir.path}/settlr_update.apk');

    if (await apkFile.exists()) {
      await apkFile.delete();
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'Settlr-Android-App';
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed with HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final sink = apkFile.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(receivedBytes / totalBytes, receivedBytes, totalBytes);
        } else {
          onProgress(0.0, receivedBytes, 0);
        }
      }
      await sink.flush();
      await sink.close();

      // Trigger native package installer via MethodChannel
      await _platform.invokeMethod('installApk', {'filePath': apkFile.path});
    } finally {
      client.close();
    }
  }

  static bool _isVersionNewer(String latest, String current) {
    if (latest.isEmpty) return false;
    final l = latest.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map(int.tryParse).toList();
    final c = current.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map(int.tryParse).toList();

    for (int i = 0; i < 3; i++) {
      final lVal = (i < l.length && l[i] != null) ? l[i]! : 0;
      final cVal = (i < c.length && c[i] != null) ? c[i]! : 0;
      if (lVal > cVal) return true;
      if (lVal < cVal) return false;
    }
    return false;
  }
}
