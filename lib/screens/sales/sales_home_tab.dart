import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

class SalesHomeTab extends StatelessWidget {
  final ValueChanged<int> onMenuSelected;

  const SalesHomeTab({super.key, required this.onMenuSelected});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final orders = appState.salesOrders;
    final draftCount = orders.where((order) => order.docStatus == 0).length;
    final pendingApproval = orders
        .where((order) => order.docStatus == 0 || order.statusText == 'On Hold')
        .length;
    final recentOrders = orders.take(5).toList();

    return RefreshIndicator(
      onRefresh: appState.refreshSalesOrders,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Total Order',
                  value: '${orders.length}',
                  icon: Icons.receipt_long_rounded,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _SummaryCard(
                  label: 'Draft',
                  value: '$draftCount',
                  icon: Icons.edit_note_rounded,
                  color: Colors.orange,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _SummaryCard(
                  label: 'Menunggu',
                  value: '$pendingApproval',
                  icon: Icons.hourglass_top_rounded,
                  color: Colors.blue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          const Text(
            'Menu Utama',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _MenuCard(
                  label: 'Order',
                  icon: Icons.receipt_long_rounded,
                  onTap: () => onMenuSelected(1),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _MenuCard(
                  label: 'Koleksi',
                  icon: Icons.account_balance_wallet_rounded,
                  onTap: () => onMenuSelected(2),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _MenuCard(
                  label: 'Kunjungan',
                  icon: Icons.location_on_rounded,
                  onTap: () => onMenuSelected(3),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _MenuCard(
                  label: 'Histori',
                  icon: Icons.history_rounded,
                  onTap: () => onMenuSelected(4),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          const Text(
            'Order Terbaru',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 10),

          if (recentOrders.isEmpty)
            const _EmptyOrders()
          else
            ...recentOrders.map(
              (order) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    order.id,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text('${order.customer} - ${order.date}'),
                  trailing: Text(
                    order.statusText,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),

          const SizedBox(height: 10),

          Text(
            value,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.slate, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),

            const SizedBox(height: 6),

            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, color: AppColors.slate),
          SizedBox(height: 8),
          Text(
            'Belum ada Sales Order',
            style: TextStyle(color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}
