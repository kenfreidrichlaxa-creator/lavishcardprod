import 'package:flutter/material.dart';
import '../../core/theme/admin_colors.dart';

/// Wraps a DataTable in a scrollable card with consistent styling.
class DataTableCard extends StatelessWidget {
  const DataTableCard({
    super.key,
    required this.columns,
    required this.rows,
    this.onSelectAll,
    this.showCheckboxColumn = false,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final ValueSetter<bool?>? onSelectAll;
  final bool showCheckboxColumn;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.sizeOf(context).width -
                  (MediaQuery.sizeOf(context).width > 900 ? 280 : 0) -
                  48,
            ),
            child: DataTable(
              showCheckboxColumn: showCheckboxColumn,
              onSelectAll: onSelectAll,
              columns: columns,
              rows: rows,
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable DataColumn with consistent style.
DataColumn adminColumn(String label, {bool numeric = false}) {
  return DataColumn(
    label: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AdminColors.brownMedium,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
    numeric: numeric,
  );
}

/// Reusable action icon button for table rows.
Widget tableAction({
  required IconData icon,
  required String tooltip,
  required VoidCallback onTap,
  Color color = AdminColors.brownMedium,
}) {
  return Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: color),
      ),
    ),
  );
}
