import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_format.dart';
import '../../widgets/dashboard/dashboard_kpi_card.dart';

class DashboardTab extends StatefulWidget {
  final VoidCallback? onTodoSelected;

  const DashboardTab({super.key, this.onTodoSelected});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();

      if (appState.salesOrders.isEmpty) appState.refreshSalesOrders();
      if (appState.purchaseOrders.isEmpty) appState.refreshPurchaseOrders();
      if (appState.warehouses.isEmpty) appState.refreshWarehouses();
      if (appState.inventory.isEmpty) appState.refreshInventory();
      if (appState.salesInvoices.isEmpty) appState.refreshSalesInvoices();
      if (appState.purchaseInvoices.isEmpty) {
        appState.refreshPurchaseInvoices();
      }
      if (!appState.hasFullOrderSummary) {
        appState.refreshOrderSummaries();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final summary = appState.dashboardSummary;
    final pendingPurchasesCount = summary.purchasePendingCount;
    final openSalesCount = summary.salesOpenCount;
    final lowStockCount = summary.stockAlerts;
    final unpaidSiCount = summary.unpaidSalesInvoices;
    final overduePiCount = summary.overduePurchaseInvoices;

    final salesStats = _SalesMoneyStats(
      total: summary.salesTotal,
      open: summary.salesOpen,
      completed: summary.salesCompleted,
      draftCount: summary.salesDraftCount,
      openCount: summary.salesOpenCount,
      completedCount: summary.salesCompletedCount,
    );
    final purchaseStats = _PurchaseMoneyStats(
      total: summary.purchaseTotal,
      pending: summary.purchasePending,
      delayed: summary.purchaseDelayed,
      draftCount: summary.purchaseDraftCount,
      pendingCount: summary.purchasePendingCount,
      completedCount: summary.purchaseCompletedCount,
    );

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await Future.wait([
          appState.refreshSalesOrders(),
          appState.refreshPurchaseOrders(),
          appState.refreshSalesInvoices(),
          appState.refreshPurchaseInvoices(),
          appState.refreshInventory(),
          appState.refreshAllSummaries(),
          appState.fetchSalesOrderApprovals(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OperationsSnapshot(
              openSales: openSalesCount,
              unpaidInvoices: unpaidSiCount,
              pendingPurchases: pendingPurchasesCount,
              stockAlerts: lowStockCount,
            ),
            if (appState.isOrderSummaryLoading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
            if (appState.orderSummaryError != null) ...[
              const SizedBox(height: 10),
              Text(
                'Summary sync failed: ${appState.orderSummaryError}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],

            const SizedBox(height: 18),

            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                onTap: widget.onTodoSelected,
                leading: CircleAvatar(
                  backgroundColor: AppColors.softGreen,
                  foregroundColor: AppColors.primary,
                  child: appState.salesOrderApprovalTodoCount > 0
                      ? Badge.count(
                          count: appState.salesOrderApprovalTodoCount,
                          backgroundColor: AppColors.danger,
                          textColor: AppColors.white,
                          child: const Icon(Icons.approval_outlined),
                        )
                      : const Icon(Icons.approval_outlined),
                ),
                title: const Text(
                  'Todo List',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  appState.salesOrderApprovalTodoCount > 0
                      ? '${appState.salesOrderApprovalTodoCount} Sales Order perlu keputusan'
                      : 'Tidak ada approval yang menunggu',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),

            const SizedBox(height: 18),

            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              children: [
                DashboardKpiCard(
                  title: 'UNPAID SALES INVOICES',
                  value: '$unpaidSiCount',
                  trend: unpaidSiCount > 0 ? 'Unpaid' : 'Clear',
                  trendColor: unpaidSiCount > 0
                      ? Colors.orange
                      : AppColors.tertiary,
                  icon: Icons.receipt_long_outlined,
                  iconColor: AppColors.primary,
                ),
                DashboardKpiCard(
                  title: 'OVERDUE PURCHASE INVOICES',
                  value: '$overduePiCount',
                  trend: overduePiCount > 0 ? 'Overdue' : 'Clear',
                  trendColor: overduePiCount > 0
                      ? Colors.red
                      : AppColors.tertiary,
                  icon: Icons.payments_outlined,
                  iconColor: overduePiCount > 0
                      ? Colors.red
                      : const Color(0xFFCA8A04),
                ),
                DashboardKpiCard(
                  title: 'PENDING PURCHASE ORDERS',
                  value: '$pendingPurchasesCount',
                  trend: 'Pending',
                  trendColor: AppColors.accentYellow,
                  icon: Icons.local_shipping_outlined,
                  iconColor: const Color(0xFFCA8A04),
                ),
                DashboardKpiCard(
                  title: 'STOCK ALERTS',
                  value: '$lowStockCount',
                  trend: lowStockCount > 0 ? 'Low Stock' : 'Clear',
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
            _FinancialSnapshot(sales: salesStats, purchases: purchaseStats),
          ],
        ),
      ),
    );
  }
}

class _SalesMoneyStats {
  final double total;
  final double open;
  final double completed;
  final int draftCount;
  final int openCount;
  final int completedCount;

  const _SalesMoneyStats({
    required this.total,
    required this.open,
    required this.completed,
    required this.draftCount,
    required this.openCount,
    required this.completedCount,
  });
}

class _PurchaseMoneyStats {
  final double total;
  final double pending;
  final double delayed;
  final int draftCount;
  final int pendingCount;
  final int completedCount;

  const _PurchaseMoneyStats({
    required this.total,
    required this.pending,
    required this.delayed,
    required this.draftCount,
    required this.pendingCount,
    required this.completedCount,
  });
}

class _FinancialSnapshot extends StatelessWidget {
  final _SalesMoneyStats sales;
  final _PurchaseMoneyStats purchases;

  const _FinancialSnapshot({required this.sales, required this.purchases});

  @override
  Widget build(BuildContext context) {
    final netValue = sales.total - purchases.total;
    final netColor = netValue >= 0 ? AppColors.success : AppColors.warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Financial Snapshot',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 10),
        _MoneyStatCard(
          title: 'Sales Orders',
          icon: Icons.point_of_sale_rounded,
          color: AppColors.primary,
          totalLabel: 'Total SO',
          totalValue: sales.total,
          rows: [
            _MoneyStatRow('Open value', sales.open, '${sales.openCount} SO'),
            _MoneyStatRow(
              'Completed',
              sales.completed,
              '${sales.completedCount} SO',
            ),
            _MoneyStatRow('Draft count', 0, '${sales.draftCount} SO'),
          ],
        ),
        const SizedBox(height: 10),
        _MoneyStatCard(
          title: 'Purchase Orders',
          icon: Icons.shopping_bag_rounded,
          color: AppColors.warning,
          totalLabel: 'Total PO',
          totalValue: purchases.total,
          rows: [
            _MoneyStatRow(
              'Pending value',
              purchases.pending,
              '${purchases.pendingCount} PO',
            ),
            _MoneyStatRow('Delayed', purchases.delayed, 'ETA risk'),
            _MoneyStatRow('Draft count', 0, '${purchases.draftCount} PO'),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: netColor.withValues(alpha: 0.16)),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: netColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: netColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sales vs Purchase',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      netValue >= 0 ? 'Positive commitment' : 'Purchase heavy',
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${netValue < 0 ? '-' : ''}Rp ${formatErpCurrency(netValue.abs())}',
                style: TextStyle(
                  color: netColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoneyStatRow {
  final String label;
  final double value;
  final String detail;

  const _MoneyStatRow(this.label, this.value, this.detail);
}

class _MoneyStatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String totalLabel;
  final double totalValue;
  final List<_MoneyStatRow> rows;

  const _MoneyStatCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.totalLabel,
    required this.totalValue,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      totalLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Rp ${formatErpCurrency(totalValue)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map((row) {
            final hasMoney = row.value > 0;
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                      ),
                    ),
                  ),
                  Text(
                    hasMoney
                        ? 'Rp ${formatErpCurrency(row.value)}'
                        : row.detail,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy,
                    ),
                  ),
                  if (hasMoney) ...[
                    const SizedBox(width: 8),
                    Text(
                      row.detail,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OperationsSnapshot extends StatelessWidget {
  final int openSales;
  final int unpaidInvoices;
  final int pendingPurchases;
  final int stockAlerts;

  const _OperationsSnapshot({
    required this.openSales,
    required this.unpaidInvoices,
    required this.pendingPurchases,
    required this.stockAlerts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prioritas Hari Ini',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _priorityMessage,
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SnapshotMetric(
                  icon: Icons.point_of_sale_rounded,
                  label: 'Open SO',
                  value: openSales,
                ),
              ),
              Expanded(
                child: _SnapshotMetric(
                  icon: Icons.receipt_long_rounded,
                  label: 'Unpaid',
                  value: unpaidInvoices,
                ),
              ),
              Expanded(
                child: _SnapshotMetric(
                  icon: Icons.shopping_bag_rounded,
                  label: 'Pending PO',
                  value: pendingPurchases,
                ),
              ),
              Expanded(
                child: _SnapshotMetric(
                  icon: Icons.warning_amber_rounded,
                  label: 'Stock',
                  value: stockAlerts,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _priorityMessage {
    if (stockAlerts > 0) {
      return 'Cek stok kritis sebelum membuat transaksi baru.';
    }
    if (unpaidInvoices > 0) {
      return 'Ada invoice sales yang perlu ditindaklanjuti.';
    }
    if (pendingPurchases > 0) {
      return 'Pantau PO yang belum selesai dan jadwal penerimaan.';
    }
    return 'Operasional terlihat aman. Tarik layar untuk sinkronisasi.';
  }
}

class _SnapshotMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _SnapshotMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.white, size: 18),
        ),
        const SizedBox(height: 7),
        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.white.withValues(alpha: 0.72),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
