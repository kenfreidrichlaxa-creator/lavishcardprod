import 'package:flutter/material.dart';

/// Standard page header with title, subtitle, and optional action button.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          if (action != null) action!
          else if (actionLabel != null && onAction != null)
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(
                actionIcon ?? Icons.add_rounded,
                size: 16,
              ),
              label: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
