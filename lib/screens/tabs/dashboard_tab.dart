import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../models/inventory_item.dart';
import '../../models/purchase_order.dart';

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
      final appState = Provider.of<AppState>(context, listen: false);
      // Refresh sales, purchase, and inventory data for dashboard
      appState.refreshSalesOrders();
      appState.refreshPurchaseOrders();
      appState.refreshInventory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    final activeSalesCount = appState.salesOrders.length;
    final pendingPurchasesCount = appState.purchaseOrders.length;
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Hello',
                    style: TextStyle(
                      fontFamily: 'HankenGrotesk',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'dashboard',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF135E39).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF135E39),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Live Sync',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF135E39),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.15,
            children: [
              _buildKpiCard(
                title: 'ACTIVE SALES',
                value: '$activeSalesCount',
                trend: '+12%',
                trendColor: AppColors.tertiary,
                icon: Icons.analytics_outlined,
                iconColor: AppColors.primary,
              ),
              _buildKpiCard(
                title: 'PENDING PO',
                value: '$pendingPurchasesCount',
                trend: 'Active',
                trendColor: AppColors.accentYellow,
                icon: Icons.local_shipping_outlined,
                iconColor: const Color(0xFFCA8A04),
              ),
              _buildKpiCard(
                title: 'STOCK ALERTS',
                value: '$lowStockCount',
                trend: lowStockCount > 0 ? 'Urgent' : 'Clear',
                trendColor: lowStockCount > 0 ? Colors.red : AppColors.tertiary,
                icon: Icons.warning_amber_outlined,
                iconColor: lowStockCount > 0
                    ? Colors.red
                    : AppColors.primaryLight,
              ),
            ],
          ),

          const SizedBox(height: 20),

          _buildDataSection(
            title: 'Recent Sales Orders',
            child: Column(
              children: recentSales.isNotEmpty
                  ? recentSales
                        .map(
                          (order) => _buildOrderRow(
                            label: order.id,
                            value: 'Rp ${order.value.toStringAsFixed(0)}',
                            subtitle: order.customer,
                            status: order.status.toString().split('.').last,
                          ),
                        )
                        .toList()
                  : [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No sales orders available yet.',
                          style: TextStyle(color: AppColors.slate),
                        ),
                      ),
                    ],
            ),
          ),

          const SizedBox(height: 14),

          _buildDataSection(
            title: 'Pending Purchase Orders',
            child: Column(
              children: pendingPurchaseOrders.isNotEmpty
                  ? pendingPurchaseOrders
                        .map(
                          (po) => _buildOrderRow(
                            label: po.id,
                            value: 'Qty ${po.itemsCount}',
                            subtitle: po.vendor,
                            status: po.status.toString().split('.').last,
                          ),
                        )
                        .toList()
                  : [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No pending POs at this time.',
                          style: TextStyle(color: AppColors.slate),
                        ),
                      ),
                    ],
            ),
          ),

          const SizedBox(height: 14),

          _buildDataSection(
            title: 'Low Stock Alerts',
            child: Column(
              children: lowStockItems.isNotEmpty
                  ? lowStockItems
                        .map((item) => _buildStockAlertRow(item))
                        .toList()
                  : [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Inventory levels are healthy.',
                          style: TextStyle(color: AppColors.slate),
                        ),
                      ),
                    ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String trend,
    required Color trendColor,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: trendColor,
                  ),
                ),
              ),
            ],
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'HankenGrotesk',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate.withOpacity(0.85),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'HankenGrotesk',
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildOrderRow({
    required String label,
    required String value,
    required String subtitle,
    required String status,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
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
                  style: const TextStyle(fontSize: 12, color: AppColors.slate),
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

  Widget _buildStockAlertRow(InventoryItem item) {
    final alertColor = item.status == StockStatus.urgent
        ? Colors.red.shade400
        : Colors.orange.shade700;
    final label = item.status == StockStatus.urgent ? 'URGENT' : 'LOW';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF7F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.warehouseId} • ${item.quantity} units',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: alertColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: alertColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
