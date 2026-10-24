import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'services/forecast_service.dart';
import 'services/ocr_service.dart';
import 'viewmodels/auth_view_model.dart';
import 'viewmodels/budget_view_model.dart';
import 'viewmodels/forecast_view_model.dart';
import 'viewmodels/transaction_view_model.dart';
import 'views/login_view.dart';

/// App root: plugs the ViewModels (MVVM) into the widget tree via Provider.
///
/// Views only see ViewModels; ViewModels only see service interfaces
/// - the dependency direction shown in Figure 8.
class ExpenseCastApp extends StatelessWidget {
  const ExpenseCastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(
          create: (_) => TransactionViewModel(ocrService: MlKitOcrService()),
        ),
        ChangeNotifierProvider(create: (_) => BudgetViewModel()),
        ChangeNotifierProvider(
          create: (_) => ForecastViewModel(service: ForecastEngine()),
        ),
      ],
      child: MaterialApp(
        title: 'ExpenseCast',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const LoginView(),
      ),
    );
  }
}
