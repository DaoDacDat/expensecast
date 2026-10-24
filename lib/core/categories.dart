import 'package:flutter/material.dart';

/// Fixed spending categories for the MVP (per mockup 5 - Budgets).
class Categories {
  static const food = 'Food';
  static const transport = 'Transportation';
  static const other = 'Other';

  static const all = <String>[food, transport, other];

  static IconData iconFor(String category) => switch (category) {
        food => Icons.restaurant_outlined,
        transport => Icons.directions_bus_outlined,
        _ => Icons.category_outlined,
      };

  static Color colorFor(String category) => switch (category) {
        food => const Color(0xFF3F8F5B),
        transport => const Color(0xFF3A6EA5),
        _ => const Color(0xFF6B7280),
      };
}
