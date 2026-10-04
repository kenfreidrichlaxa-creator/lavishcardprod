import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Auto-update checker for the Lavish Prima Admin desktop app.
///
/// On startup the app asks GitHub for the latest published release of the
/// public releases repo. If the release tag is a newer semantic version than
/// the running build, [checkForUpdate] returns an [AppUpdateInfo]; the UI then
/// offers to download the packaged Windows build (a `.zip` asset) into the
/// user's Downloads folder and prompts a restart.
abstract final class UpdateService {
  // Public GitHub repo that hosts the Windows release zips.
  static const String _owner = 'kenfreidrichlaxa-creator';
  static const String _repo = 'lavishcardprod';

  static Uri get _latestReleaseApi =>
      Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest');

  static String get releasesPageUrl =>
      'https://github.com/$_owner/$_repo/releases/latest';

  /// Returns update info when a newer release is available, otherwise null.
  /// Never throws — network/parse failures resolve to null so startup is safe.
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = _Version.parse(info.version);

      final resp = await http
          .get(_latestReleaseApi, headers: {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'lavish-admin-updater',
          })
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?)?.trim() ?? '';
      final latest = _Version.parse(tag);
      if (latest == null || current == null) return null;
      if (!latest.isNewerThan(current)) return null;

      // Find a downloadable Windows zip asset.
      final assets = (data['assets'] as List<dynamic>? ?? []);
      String? downloadUrl;
      String? assetName;
      int assetSize = 0;
      for (final a in assets) {
        final m = a as Map<String, dynamic>;
        final name = (m['name'] as String?) ?? '';
        if (name.toLowerCase().endsWith('.zip')) {
          downloadUrl = m['browser_download_url'] as String?;
          assetName = name;
          assetSize = (m['size'] as int?) ?? 0;
          break;
        }
      }

      return AppUpdateInfo(
        currentVersion: info.version,
        latestVersion: latest.raw,
        releaseNotes: (data['body'] as String?)?.trim() ?? '',
        downloadUrl: downloadUrl,
        assetName: assetName,
        assetSize: assetSize,
        releasePageUrl: (data['html_url'] as String?) ?? releasesPageUrl,
      );
    } catch (_) {
      return null;
    }
  }

  /// Downloads the release zip to the Downloads folder (falls back to temp).
  /// [onProgress] reports 0.0–1.0 when the total size is known.
  /// Returns the saved file path, or throws on failure.
  static Future<String> downloadUpdate(
    AppUpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    final url = update.downloadUrl;
    if (url == null || url.isEmpty) {
      throw const UpdateException('No downloadable file in the latest release.');
    }

    final dir = await _downloadDir();
    final fileName = update.assetName ??
        'lavish_admin-${update.latestVersion}-windows.zip';
    final savePath = '${dir.path}${Platform.pathSeparator}$fileName';

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      req.headers['User-Agent'] = 'lavish-admin-updater';
      final resp = await client.send(req);
      if (resp.statusCode != 200) {
        throw UpdateException('Download failed (HTTP ${resp.statusCode}).');
      }

      final total = resp.contentLength ?? update.assetSize;
      final file = File(savePath);
      final sink = file.openWrite();
      int received = 0;
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      }
      await sink.close();
      return savePath;
    } finally {
      client.close();
    }
  }

  static Future<Directory> _downloadDir() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return downloads;
    } catch (_) {/* fall through */}
    return getTemporaryDirectory();
  }
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.assetName,
    required this.assetSize,
    required this.releasePageUrl,
  });

  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String? downloadUrl;
  final String? assetName;
  final int assetSize;
  final String releasePageUrl;

  bool get hasDownloadableAsset =>
      downloadUrl != null && downloadUrl!.isNotEmpty;
}

class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Minimal semantic version parser tolerant of a leading `v` and build suffix.
class _Version {
  const _Version(this.major, this.minor, this.patch, this.raw);

  final int major;
  final int minor;
  final int patch;
  final String raw;

  static _Version? parse(String? input) {
    if (input == null) return null;
    var s = input.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    // Drop build metadata / pre-release suffix (e.g. 1.2.3+4 or 1.2.3-beta).
    s = s.split('+').first.split('-').first;
    final parts = s.split('.');
    int at(int i) =>
        i < parts.length ? (int.tryParse(parts[i].trim()) ?? 0) : 0;
    if (parts.isEmpty) return null;
    return _Version(at(0), at(1), at(2), input.trim());
  }

  bool isNewerThan(_Version other) {
    if (major != other.major) return major > other.major;
    if (minor != other.minor) return minor > other.minor;
    return patch > other.patch;
  }
}
