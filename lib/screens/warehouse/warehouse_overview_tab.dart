import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/inventory_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

class WarehouseOverviewTab extends StatelessWidget {
  final ValueChanged<int> onMenuSelected;

  const WarehouseOverviewTab({super.key, required this.onMenuSelected});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lowStock = state.inventory
        .where((item) => item.status != StockStatus.inStock)
        .length;
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          state.refreshWarehouses(),
          state.refreshInventory(),
          state.refreshStockEntries(),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          const Text(
            'Dashboard Warehouse',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pilih aktivitas yang ingin dikerjakan.',
            style: TextStyle(color: AppColors.slate),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Gudang',
                  value: '${state.warehouses.length}',
                  icon: Icons.warehouse_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'Peringatan stok',
                  value: '$lowStock',
                  icon: Icons.warning_amber_rounded,
                  color: lowStock > 0 ? AppColors.warning : AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _MenuCard(
            title: 'Operasi Gudang',
            subtitle: 'Transfer, penerimaan, pengeluaran, dan stock opname',
            icon: Icons.swap_horiz_rounded,
            onTap: () => onMenuSelected(1),
          ),
          _MenuCard(
            title: 'Monitoring Stok',
            subtitle: 'Cek stok realtime dan peringatan stok minimum',
            icon: Icons.inventory_2_rounded,
            available: true,
            onTap: () => onMenuSelected(2),
          ),
          _MenuCard(
            title: 'Quality Control',
            subtitle: 'Incoming QC, hasil produksi, reject, dan approval',
            icon: Icons.fact_check_rounded,
            onTap: () => onMenuSelected(3),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          foregroundColor: color,
          child: Icon(icon),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: AppColors.slate, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool available;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.available = false,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.softGreen,
        foregroundColor: AppColors.primary,
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
      trailing: available
          ? const Icon(Icons.arrow_forward_ios_rounded, size: 16)
          : const Chip(label: Text('Berikutnya')),
    ),
  );
}
