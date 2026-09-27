import 'package:flutter/material.dart';

/// Danh mục chi tiêu cố định của MVP (theo mockup 5 - Budgets).
class Categories {
  static const groceries = 'Groceries';
  static const transport = 'Transport';
  static const eatingOut = 'Eating out';
  static const utilities = 'Utilities';
  static const other = 'Other';

  static const all = <String>[
    groceries,
    transport,
    eatingOut,
    utilities,
    other,
  ];

  static IconData iconFor(String category) => switch (category) {
        groceries => Icons.local_grocery_store_outlined,
        transport => Icons.directions_bus_outlined,
        eatingOut => Icons.restaurant_outlined,
        utilities => Icons.bolt_outlined,
        _ => Icons.category_outlined,
      };

  static Color colorFor(String category) => switch (category) {
        groceries => const Color(0xFF3F8F5B),
        transport => const Color(0xFF3A6EA5),
        eatingOut => const Color(0xFFC2703D),
        utilities => const Color(0xFF7A5EA8),
        _ => const Color(0xFF6B7280),
      };
}
