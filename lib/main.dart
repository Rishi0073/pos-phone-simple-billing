import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/billing/data/repositories/bill_repository.dart';
import 'features/billing/data/repositories/sqflite_repositories.dart';
import 'features/billing/presentation/controllers/billing_controller.dart';
import 'features/billing/presentation/screens/items_screen.dart';
import 'features/billing/presentation/screens/main_billing_screen.dart';
import 'features/checkout/domain/services/bill_saver.dart';
import 'features/checkout/presentation/screens/checkout_screen.dart';
import 'features/history/presentation/screens/history_screen.dart';
import 'features/printer/data/usb_thermal_printer_service.dart';
import 'features/printer/domain/thermal_printer_service.dart';
import 'features/sales/presentation/screens/sales_screen.dart';
import 'features/settings/domain/shop_settings.dart';
import 'features/settings/presentation/controllers/settings_controller.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'shared/services/voice_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SimpleBillingApp());
}

class SimpleBillingApp extends StatelessWidget {
  const SimpleBillingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: AppDatabase.instance),
        Provider<BillRepository>(
          create: (context) =>
              SqfliteBillRepository(context.read<AppDatabase>()),
        ),
        Provider<SettingsRepository>(
          create: (context) => SqfliteSettingsRepository(
            context.read<AppDatabase>(),
            context.read<BillRepository>(),
          ),
        ),
        ChangeNotifierProvider<SettingsController>(
          create: (context) =>
              SettingsController(context.read<SettingsRepository>())..load(),
        ),
        ChangeNotifierProvider<BillingController>(
          create: (_) => BillingController(),
        ),
        ChangeNotifierProvider<ThermalPrinterService>(
          create: (_) => UsbThermalPrinterService()..initialize(),
        ),
        Provider<BillSaver>(
          create: (context) => BillSaver(context.read<BillRepository>()),
        ),
        ChangeNotifierProvider<VoiceService>(
          create: (_) => VoiceService()..init(),
        ),
      ],
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    return MaterialApp(
      title: 'Simple Billing',
      debugShowCheckedModeBanner: false,
      theme: settings.highContrast ? AppTheme.highContrast : AppTheme.light,
      builder: (context, child) {
        return MediaQuery(
          data: settings.largeMode
              ? MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.12))
              : MediaQuery.of(context),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const HomeShell(),
      routes: {
        '/items': (_) => const ItemsScreen(),
        '/checkout': (_) => const CheckoutScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final screens = [
      MainBillingScreen(shopName: settings.shopName),
      const HistoryScreen(),
      const SalesScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'BILL',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'HISTORY',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'SALES',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'SETTINGS',
          ),
        ],
      ),
    );
  }
}