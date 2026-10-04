import 'package:flutter/material.dart';
import '../../core/theme/admin_colors.dart';

/// Reusable search bar for all admin list screens.
class AdminSearchBar extends StatefulWidget {
  const AdminSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.width,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final double? width;

  @override
  State<AdminSearchBar> createState() => _AdminSearchBarState();
}

class _AdminSearchBarState extends State<AdminSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? 320,
      height: 40,
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: const TextStyle(
          fontSize: 13,
          color: AdminColors.charcoal,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                    setState(() {});
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          isDense: true,
        ),
        onTapOutside: (e) => FocusScope.of(context).unfocus(),
      ),
    );
  }
}
