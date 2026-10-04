import 'package:flutter/material.dart';
import '../../core/theme/admin_colors.dart';

/// A titled content card used in profile/detail views.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const Spacer(),
                ?trailing,
              ],
            ),
          ),
          const Divider(height: 16),
          Padding(
            padding: padding ?? const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// A single label-value detail row used inside SectionCard.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueWidget,
    this.isLast = false,
  });

  final String label;
  final String value;
  final Widget? valueWidget;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AdminColors.brownLight,
              ),
            ),
          ),
          Expanded(
            child: valueWidget ??
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AdminColors.charcoal,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
