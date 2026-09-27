import 'package:flutter/material.dart';

import '../core/categories.dart';

/// Ô chọn danh mục dùng chung cho màn hình Review và Manual Entry.
///
/// Dùng bottom sheet thay cho DropdownButtonFormField để vùng chạm lớn hơn
/// (yêu cầu usability ở mục 1.2.1) và không phụ thuộc vào API dropdown vốn
/// thay đổi giữa các phiên bản Flutter.
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.highlighted = false,
  });

  final String value;
  final ValueChanged<String> onChanged;

  /// Tô nền nhấn khi đây là gợi ý từ OCR (mockup 4).
  final bool highlighted;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Category',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
            ),
            for (final c in Categories.all)
              ListTile(
                leading: Icon(Categories.iconFor(c),
                    color: Categories.colorFor(c)),
                title: Text(c),
                trailing: c == value ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(ctx).pop(c),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          fillColor: highlighted
              ? theme.colorScheme.secondaryContainer
              : theme.inputDecorationTheme.fillColor,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Row(
          children: [
            Icon(Categories.iconFor(value),
                size: 18, color: Categories.colorFor(value)),
            const SizedBox(width: 10),
            Text(value, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
