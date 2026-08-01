import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/dashboard/dashboard_module_launcher.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();

      if (appState.canUseSales && appState.salesOrders.isEmpty) {
        appState.refreshSalesOrders();
      }
      if (appState.canUsePurchase && appState.purchaseOrders.isEmpty) {
        appState.refreshPurchaseOrders();
      }
      if ((appState.canUseStock || appState.canUseWarehouse) &&
          appState.warehouses.isEmpty) {
        appState.refreshWarehouses();
      }
      if ((appState.canUseStock || appState.canUseWarehouse) &&
          appState.inventory.isEmpty) {
        appState.refreshInventory();
      }
      if (appState.canUseApprovals) {
        appState.fetchApprovalTodos();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final showStockKpi = appState.canUseStock || appState.canUseWarehouse;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await Future.wait([
          if (appState.canUseSales) appState.refreshSalesOrders(),
          if (appState.canUsePurchase) appState.refreshPurchaseOrders(),
          if (showStockKpi) appState.refreshInventory(),
          if (appState.canUseApprovals)
            appState.fetchApprovalTodos(forceRefresh: true),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [DashboardModuleLauncher()],
        ),
      ),
    );
  }
}
