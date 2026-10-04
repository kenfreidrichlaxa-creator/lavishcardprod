import 'package:flutter/material.dart';
import '../../core/theme/admin_colors.dart';
import '../../core/utils/formatters.dart';

/// A slim amber banner shown at the top of a screen when it is displaying
/// cached (stale) data because the last network fetch failed.
///
/// Pass [cachedAt] to show the age of the cache, and [onRetry] to wire up
/// the refresh button.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.cachedAt,
    this.onRetry,
  });

  final DateTime? cachedAt;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final age = cachedAt == null ? '' : ' · ${Fmt.relativeDate(cachedAt!)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AdminColors.warning.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 15, color: AdminColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline — showing cached data$age',
              style: const TextStyle(
                fontSize: 12,
                color: AdminColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRetry != null)
            GestureDetector(
              onTap: onRetry,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        size: 14, color: AdminColors.warning),
                    SizedBox(width: 3),
                    Text('Retry',
                        style: TextStyle(
                          fontSize: 12,
                          color: AdminColors.warning,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
