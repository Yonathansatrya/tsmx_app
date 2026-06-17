import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_format.dart';
import '../../widgets/erp/erp_empty_state.dart';
import 'sales_ui.dart';

class SalesOverviewTab extends StatelessWidget {
  final ValueChanged<int> onMenuSelected;

  const SalesOverviewTab({super.key, required this.onMenuSelected});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final orders = state.salesOrders;
    final outstanding = state.salesInvoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.outstandingAmount,
    );
    return RefreshIndicator(
      onRefresh: state.refreshDataForCurrentRole,
      child: ListView(
        padding: SalesUi.screenPadding,
        children: [
          Row(
            children: [
              Expanded(
                child: _Metric(label: 'Order', value: '${orders.length}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  label: 'Draft',
                  value: '${orders.where((o) => o.docStatus == 0).length}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  label: 'Outstanding',
                  value: 'Rp ${formatErpCurrency(outstanding)}',
                ),
              ),
            ],
          ),
          SalesUi.gap(18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Menu(
                label: 'Sales Order',
                icon: Icons.receipt_long,
                tap: () => onMenuSelected(1),
              ),
              _Menu(
                label: 'Collection',
                icon: Icons.account_balance_wallet,
                tap: () => onMenuSelected(2),
              ),
              _Menu(
                label: 'Sales Visit',
                icon: Icons.storefront,
                tap: () => onMenuSelected(3),
              ),
              _Menu(
                label: 'Histori',
                icon: Icons.history,
                tap: () => onMenuSelected(4),
              ),
            ],
          ),
          SalesUi.gap(22),
          const Text(
            'Order Terbaru',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          SalesUi.gap(10),
          if (orders.isEmpty)
            const ErpEmptyState(title: 'Belum ada Sales Order')
          else
            ...orders
                .take(5)
                .map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SalesInfoCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.id,
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${order.customer} - ${order.date}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.slate,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            order.statusText,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 56),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryDark.withValues(alpha: 0.025),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.slate),
        ),
      ],
    ),
  );
}

class _Menu extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback tap;
  const _Menu({required this.label, required this.icon, required this.tap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 42) / 2,
    child: SalesInfoCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      onTap: tap,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.primary, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
