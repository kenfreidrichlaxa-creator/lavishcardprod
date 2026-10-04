import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_service.dart';

/// Shows the "update available" flow (Option A):
///   1. Ask the user if they want to download the new version.
///   2. Download with a progress bar.
///   3. On success, prompt to open the folder and restart.
///
/// Safe to call once at startup; does nothing if [update] is null.
abstract final class UpdatePrompt {
  static Future<void> maybeShow(
    BuildContext context,
    AppUpdateInfo? update,
  ) async {
    if (update == null) return;
    if (!context.mounted) return;

    final wantsUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version (v${update.latestVersion}) is available.\n'
              'You are on v${update.currentVersion}.',
            ),
            if (update.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('What\'s new:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Text(update.releaseNotes),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(update.hasDownloadableAsset
                ? 'Download update'
                : 'Open download page'),
          ),
        ],
      ),
    );

    if (wantsUpdate != true) return;
    if (!context.mounted) return;

    // No zip attached — just open the releases page in the browser.
    if (!update.hasDownloadableAsset) {
      await _openUrl(update.releasePageUrl);
      return;
    }

    await _downloadWithProgress(context, update);
  }

  static Future<void> _downloadWithProgress(
    BuildContext context,
    AppUpdateInfo update,
  ) async {
    final progress = ValueNotifier<double>(0);
    String? savedPath;
    Object? error;

    final downloadFuture = UpdateService.downloadUpdate(
      update,
      onProgress: (p) => progress.value = p,
    ).then((path) => savedPath = path).catchError((e) => error = e);

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // Close this dialog when the download settles.
        downloadFuture.whenComplete(() {
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
        });
        return AlertDialog(
          title: const Text('Downloading Update'),
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, value, __) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: value > 0 ? value : null),
                  const SizedBox(height: 12),
                  Text(value > 0
                      ? '${(value * 100).toStringAsFixed(0)}%'
                      : 'Starting…'),
                ],
              );
            },
          ),
        );
      },
    );

    if (!context.mounted) return;

    if (error != null || savedPath == null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Download Failed'),
          content: Text(
            'Could not download the update.\n${error ?? 'Unknown error'}\n\n'
            'You can download it manually from the releases page.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _openUrl(update.releasePageUrl);
              },
              child: const Text('Open download page'),
            ),
          ],
        ),
      );
      return;
    }

    // Success — tell the user how to apply it.
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Downloaded'),
        content: Text(
          'Version ${update.latestVersion} was downloaded to:\n\n$savedPath\n\n'
          'Close this app, unzip the file, and replace the current app folder '
          'with the new one. Then reopen Lavish Prima Admin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _revealInExplorer(savedPath!);
            },
            child: const Text('Open folder'),
          ),
        ],
      ),
    );
  }

  static Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static void _revealInExplorer(String filePath) {
    try {
      // Open Windows Explorer with the downloaded file selected.
      Process.start('explorer.exe', ['/select,', filePath]);
    } catch (_) {/* best-effort */}
  }
}
