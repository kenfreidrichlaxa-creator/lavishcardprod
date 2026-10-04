import 'package:flutter/material.dart';
import '../../core/theme/admin_colors.dart';

/// Horizontal scrollable filter chip bar.
class FilterBar<T> extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.labelBuilder,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: 8,
        children: options.map((opt) {
          final isSelected = opt == selected;
          final label = labelBuilder?.call(opt) ?? opt.toString();
          return FilterChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => onSelected(opt),
            showCheckmark: false,
            selectedColor: AdminColors.gold,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected ? AdminColors.gold : AdminColors.beigeDeep,
            ),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AdminColors.brownMedium,
              fontSize: 12,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          );
        }).toList(),
      ),
    );
  }
}
