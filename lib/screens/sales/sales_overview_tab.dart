import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_format.dart';
import '../../widgets/erp/erp_empty_state.dart';

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
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
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
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
          const SizedBox(height: 24),
          const Text(
            'Order Terbaru',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          if (orders.isEmpty)
            const ErpEmptyState(title: 'Belum ada Sales Order')
          else
            ...orders
                .take(5)
                .map(
                  (order) => Card(
                    child: ListTile(
                      title: Text(
                        order.id,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text('${order.customer} - ${order.date}'),
                      trailing: Text(order.statusText),
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
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
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
    width: (MediaQuery.sizeOf(context).width - 40) / 2,
    child: Card(
      child: ListTile(
        onTap: tap,
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    ),
  );
}
