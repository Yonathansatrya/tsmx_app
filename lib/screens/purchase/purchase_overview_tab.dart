import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/purchase_order.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_format.dart';
import '../../widgets/erp/erp_empty_state.dart';
import '../../widgets/erp/erp_status_badge.dart';
import 'purchase_order/create_purchase_order_screen.dart';

class PurchaseOverviewTab extends StatelessWidget {
  final ValueChanged<int> onMenuSelected;

  const PurchaseOverviewTab({super.key, required this.onMenuSelected});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final outstandingPo = state.purchaseOrders
        .where(
          (po) =>
              po.statusKey != PurchaseOrderStatusKey.completed &&
              po.statusKey != PurchaseOrderStatusKey.cancelled &&
              po.statusKey != PurchaseOrderStatusKey.closed,
        )
        .length;
    final outstandingDebt = state.purchaseInvoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.outstandingAmount,
    );

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          state.refreshBuyingSummaries(),
          state.refreshPurchaseOrders(),
          state.refreshPurchaseReceipts(),
          state.refreshPurchaseInvoices(),
          state.refreshInventory(),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          const _SectionHeader(
            title: 'Dashboard Purchase',
            subtitle:
                'Pantau pembelian, penerimaan, invoice, dan request barang',
            icon: Icons.shopping_bag_rounded,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Open PO',
                  value: '$outstandingPo',
                  icon: Icons.pending_actions_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  label: 'Hutang',
                  value: 'Rp ${formatErpCurrency(outstandingDebt)}',
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _QuickActionCard(
            title: 'Create Purchase Order',
            subtitle: 'Buat PO langsung dari mobile',
            icon: Icons.add_shopping_cart_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CreatePurchaseOrderScreen(),
              ),
            ),
          ),
          _QuickActionCard(
            title: 'Purchase Receipt',
            subtitle: 'Receive barang, foto penerimaan, QC, dan selisih qty',
            icon: Icons.move_to_inbox_rounded,
            onTap: () => onMenuSelected(2),
          ),
          _QuickActionCard(
            title: 'Purchase Invoice',
            subtitle:
                'Monitor invoice supplier, hutang, due date, dan approval',
            icon: Icons.receipt_long_rounded,
            onTap: () => onMenuSelected(3),
          ),
          _QuickActionCard(
            title: 'Material Request',
            subtitle: 'Request barang antar departemen dan planning pembelian',
            icon: Icons.assignment_outlined,
            onTap: () => onMenuSelected(4),
          ),
          const SizedBox(height: 18),
          const _SectionHeader(
            title: 'Purchase Order Terbaru',
            subtitle: 'Dokumen terakhir yang perlu dipantau',
            icon: Icons.history_rounded,
          ),
          const SizedBox(height: 10),
          if (state.purchaseOrders.isEmpty)
            const ErpEmptyState(
              title: 'Belum ada Purchase Order',
              message: 'Tekan Create Purchase Order untuk mulai.',
            )
          else
            ...state.purchaseOrders.take(5).map(_recentPoCard),
        ],
      ),
    );
  }

  Widget _recentPoCard(PurchaseOrder po) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    po.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${po.vendor} - ${po.eta}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ErpStatusBadge(statusText: po.statusText),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        backgroundColor: AppColors.softGreen,
        foregroundColor: AppColors.primary,
        child: Icon(icon),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.slate, fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 86),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: AppColors.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.slate,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.softGreen,
                foregroundColor: AppColors.primary,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
            ],
          ),
        ),
      ),
    ),
  );
}
