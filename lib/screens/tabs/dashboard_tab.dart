import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/inventory_item.dart';
import '../../models/purchase_order.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/dashboard/dashboard_data_section.dart';
import '../../widgets/dashboard/dashboard_kpi_card.dart';
import '../../widgets/dashboard/dashboard_stock_alert_row.dart';

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

      if (appState.salesOrders.isEmpty) {
        appState.refreshSalesOrders();
      }

      if (appState.purchaseOrders.isEmpty) {
        appState.refreshPurchaseOrders();
      }

      if (appState.inventory.isEmpty) {
        appState.refreshInventory();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final activeSalesCount = appState.salesOrders.length;

    final pendingPurchasesCount = appState.purchaseOrders
        .where((po) => po.status != PurchaseOrderStatus.completed)
        .length;

    final lowStockCount = appState.inventory
        .where((item) => item.status != StockStatus.inStock)
        .length;

    final recentSales = appState.salesOrders.take(3).toList();

    final pendingPurchaseOrders = appState.purchaseOrders
        .where((po) => po.status != PurchaseOrderStatus.completed)
        .take(3)
        .toList();

    final lowStockItems = appState.inventory
        .where((item) => item.status != StockStatus.inStock)
        .take(4)
        .toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await Future.wait([
          appState.refreshSalesOrders(),
          appState.refreshPurchaseOrders(),
          appState.refreshInventory(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashboardHeader(userName: appState.currentUser),

            const SizedBox(height: 20),

            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.15,
              children: [
                DashboardKpiCard(
                  title: 'ACTIVE SALES',
                  value: '$activeSalesCount',
                  trend: '+12%',
                  trendColor: AppColors.tertiary,
                  icon: Icons.analytics_outlined,
                  iconColor: AppColors.primary,
                ),
                DashboardKpiCard(
                  title: 'PENDING PO',
                  value: '$pendingPurchasesCount',
                  trend: 'Active',
                  trendColor: AppColors.accentYellow,
                  icon: Icons.local_shipping_outlined,
                  iconColor: const Color(0xFFCA8A04),
                ),
                DashboardKpiCard(
                  title: 'STOCK ALERTS',
                  value: '$lowStockCount',
                  trend: lowStockCount > 0 ? 'Urgent' : 'Clear',
                  trendColor: lowStockCount > 0
                      ? Colors.red
                      : AppColors.tertiary,
                  icon: Icons.warning_amber_outlined,
                  iconColor: lowStockCount > 0
                      ? Colors.red
                      : AppColors.primaryLight,
                ),
              ],
            ),

            const SizedBox(height: 20),

            DashboardDataSection(
              title: 'Recent Sales Orders',
              child: recentSales.isNotEmpty
                  ? Column(
                      children: recentSales.map((order) {
                        return _DashboardOrderRow(
                          label: order.id,
                          value: 'Rp ${order.value.toStringAsFixed(0)}',
                          subtitle: order.customer,
                          status: _formatEnumStatus(order.status.name),
                        );
                      }).toList(),
                    )
                  : const _EmptySectionText('No sales orders available yet.'),
            ),

            const SizedBox(height: 14),

            DashboardDataSection(
              title: 'Pending Purchase Orders',
              child: pendingPurchaseOrders.isNotEmpty
                  ? Column(
                      children: pendingPurchaseOrders.map((po) {
                        return _DashboardOrderRow(
                          label: po.id,
                          value: 'Qty ${po.itemsCount}',
                          subtitle: po.vendor,
                          status: _formatEnumStatus(po.status.name),
                        );
                      }).toList(),
                    )
                  : const _EmptySectionText('No pending POs at this time.'),
            ),

            const SizedBox(height: 14),

            DashboardDataSection(
              title: 'Low Stock Alerts',
              child: lowStockItems.isNotEmpty
                  ? Column(
                      children: lowStockItems.map((item) {
                        return DashboardStockAlertRow(item: item);
                      }).toList(),
                    )
                  : const _EmptySectionText('Inventory levels are healthy.'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String? userName;

  const _DashboardHeader({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Dashboard overview',
              style: TextStyle(fontSize: 12, color: AppColors.primaryLight),
            ),
          ],
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              _LiveDot(),
              SizedBox(width: 6),
              Text(
                'Live Sync',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _EmptySectionText extends StatelessWidget {
  final String message;

  const _EmptySectionText(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.slate, fontSize: 12),
      ),
    );
  }
}

String _formatEnumStatus(String raw) {
  if (raw.isEmpty) return 'Unknown';

  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final char = raw[i];
    final isUpper =
        char == char.toUpperCase() && char != char.toLowerCase();

    if (i > 0 && isUpper) {
      buffer.write(' ');
    }
    buffer.write(i == 0 ? char.toUpperCase() : char);
  }

  return buffer.toString();
}

class _DashboardOrderRow extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final String status;

  const _DashboardOrderRow({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.slate,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
