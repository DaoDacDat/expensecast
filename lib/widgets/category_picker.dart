import 'package:flutter/material.dart';

import '../core/categories.dart';

/// Category picker shared by the Review and Manual Entry screens.
///
/// Uses a bottom sheet instead of DropdownButtonFormField for a larger touch target
/// (usability requirement in section 1.2.1) and to avoid depending on the dropdown API, which
/// changes between Flutter versions.
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.highlighted = false,
  });

  final String value;
  final ValueChanged<String> onChanged;

  /// Highlight the background when this is a suggestion from OCR (mockup 4).
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
