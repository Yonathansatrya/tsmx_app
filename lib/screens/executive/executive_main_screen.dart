import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../shared/role_main_screen.dart';

class ExecutiveMainScreen extends StatelessWidget {
  const ExecutiveMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleMainScreen(
      title: 'TMSX Hub Executive',
      fallbackUsername: 'Director',
      onInitialize: (state) async {
        await state.refreshAllSummaries();
        await Future.wait([
          state.refreshSalesOrders(),
          state.refreshPurchaseOrders(),
          state.refreshInventory(),
          state.fetchSalesOrderApprovals(),
        ]);
      },
      screensBuilder: (_) => [const _ExecutiveOverviewTab()],
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          selectedIcon: Icon(Icons.insights_rounded),
          label: 'Monitoring',
        ),
      ],
    );
  }
}

class _ExecutiveOverviewTab extends StatelessWidget {
  const _ExecutiveOverviewTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final summary = state.dashboardSummary;
    final todoCount =
        state.salesOrderApprovalTodoCount + state.purchaseApprovalTodoCount;

    return RefreshIndicator(
      onRefresh: () async {
        await state.refreshAllSummaries();
        await state.fetchSalesOrderApprovals();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Text(
            'Executive Dashboard',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ringkasan lintas divisi untuk ${state.selectedSiteName.isNotEmpty ? state.selectedSiteName : 'tenant aktif'}',
            style: const TextStyle(
              color: AppColors.slate,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _KpiGrid(
            items: [
              _KpiItem('Open Sales', '${summary.salesOpenCount}', Icons.point_of_sale_rounded),
              _KpiItem('Unpaid SI', '${summary.unpaidSalesInvoices}', Icons.receipt_long_rounded),
              _KpiItem('Pending PO', '${summary.purchasePendingCount}', Icons.shopping_bag_rounded),
              _KpiItem('Stock Alert', '${summary.stockAlerts}', Icons.warning_amber_rounded),
              _KpiItem('Approval', '$todoCount', Icons.checklist_rounded),
              _KpiItem('Warehouse', '${state.warehouses.length}', Icons.warehouse_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiItem {
  final String label;
  final String value;
  final IconData icon;

  const _KpiItem(this.label, this.value, this.icon);
}

class _KpiGrid extends StatelessWidget {
  final List<_KpiItem> items;

  const _KpiGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        return SizedBox(
          width: (MediaQuery.sizeOf(context).width - 42) / 2,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: AppColors.primary, size: 20),
                const SizedBox(height: 10),
                Text(
                  item.value,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  item.label,
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
