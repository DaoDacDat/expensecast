import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/budget_view_model.dart';
import '../viewmodels/forecast_view_model.dart';
import '../viewmodels/transaction_view_model.dart';
import 'budget_view.dart';
import 'home_view.dart';
import 'insights_view.dart';
import 'more_view.dart';

/// Tab host ứng với khung nét đứt "Bottom navigation bar" trong Figure 9:
/// mọi đích đến bên trong khung này cách nhau đúng một lần chạm.
class ShellView extends StatefulWidget {
  const ShellView({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<ShellView> {
  late int _index = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    // Tính dự báo lần đầu sau khi frame đầu tiên được dựng.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshForecast());
  }

  void _refreshForecast() {
    final tx = context.read<TransactionViewModel>();
    final budgets = context.read<BudgetViewModel>();
    context
        .read<ForecastViewModel>()
        .refreshForecast(tx.transactions, budgets.budgets);
  }

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
          if (i == 1) _refreshForecast();
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
