import 'package:flutter/material.dart';

import '../shared/role_main_screen.dart';
import 'warehouse_inventory_tab.dart';
import 'warehouse_operations_tab.dart';
import 'warehouse_overview_tab.dart';
import 'warehouse_quality_tab.dart';

class WarehouseMainScreen extends StatelessWidget {
  const WarehouseMainScreen({super.key});

  @override
  Widget build(BuildContext context) => RoleMainScreen(
    title: 'TMSX WAREHOUSE',
    fallbackUsername: 'Warehouse',
    onInitialize: (state) async {
      await Future.wait([
        state.refreshWarehouses(),
        state.refreshInventory(),
        state.refreshStockEntries(),
      ]);
    },
    screensBuilder: (onMenuSelected) => [
      WarehouseOverviewTab(onMenuSelected: onMenuSelected),
      const WarehouseOperationsTab(),
      const WarehouseInventoryTab(),
      const WarehouseQualityTab(),
    ],
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Beranda',
      ),
      NavigationDestination(
        icon: Icon(Icons.swap_horiz_outlined),
        selectedIcon: Icon(Icons.swap_horiz_rounded),
        label: 'Operasi',
      ),
      NavigationDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2_rounded),
        label: 'Stok',
      ),
      NavigationDestination(
        icon: Icon(Icons.fact_check_outlined),
        selectedIcon: Icon(Icons.fact_check_rounded),
        label: 'QC',
      ),
    ],
  );
}
