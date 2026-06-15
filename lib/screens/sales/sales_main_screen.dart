import 'package:flutter/material.dart';

import '../shared/role_main_screen.dart';
import 'sales_collection_tab.dart';
import 'sales_history_tab.dart';
import 'sales_order_tab.dart';
import 'sales_overview_tab.dart';
import 'sales_visit_tab.dart';

class SalesMainScreen extends StatelessWidget {
  const SalesMainScreen({super.key});

  @override
  Widget build(BuildContext context) => RoleMainScreen(
    title: 'TMSX SALES TEAM',
    fallbackUsername: 'Salesman',
    onInitialize: (state) => state.refreshDataForCurrentRole(),
    screensBuilder: (onMenuSelected) => [
      SalesOverviewTab(onMenuSelected: onMenuSelected),
      const SalesOrderTab(),
      const SalesCollectionTab(),
      const SalesVisitTab(),
      const SalesHistoryTab(),
    ],
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Beranda',
      ),
      NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long_rounded),
        label: 'Order',
      ),
      NavigationDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet_rounded),
        label: 'Koleksi',
      ),
      NavigationDestination(
        icon: Icon(Icons.location_on_outlined),
        selectedIcon: Icon(Icons.location_on_rounded),
        label: 'Kunjungan',
      ),
      NavigationDestination(
        icon: Icon(Icons.history_outlined),
        selectedIcon: Icon(Icons.history_rounded),
        label: 'Histori',
      ),
    ],
  );
}
