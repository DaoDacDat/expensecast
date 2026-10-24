import 'package:flutter/material.dart';

import 'budget_view.dart';
import 'home_view.dart';
import 'insights_view.dart';
import 'more_view.dart';

/// Tab host corresponding to the dashed "Bottom navigation bar" frame in Figure 9:
/// every destination inside this frame is exactly one tap apart.
class ShellView extends StatefulWidget {
  const ShellView({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<ShellView> {
  late int _index = widget.initialIndex;

  void goToTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeView(onSeeInsights: () => goToTab(1)),
      const InsightsView(),
      const BudgetView(),
      const MoreView(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Budgets',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
