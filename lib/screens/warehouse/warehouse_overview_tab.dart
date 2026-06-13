import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/inventory_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import 'warehouse_widgets.dart';

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
        padding: warehousePagePadding,
        children: [
          const WarehouseSectionHeader(
            title: 'Dashboard Warehouse',
            subtitle: 'Ringkasan stok dan akses aktivitas gudang',
            icon: Icons.dashboard_rounded,
          ),
          warehouseSectionGap,
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
          warehouseSectionGap,
          const WarehouseSectionHeader(
            title: 'Menu Utama',
            subtitle: 'Pilih area kerja sesuai kebutuhan',
            icon: Icons.apps_rounded,
          ),
          const SizedBox(height: 12),
          WarehouseActionCard(
            title: 'Operasi Gudang',
            subtitle: 'Transfer, penerimaan, pengeluaran, dan stock opname',
            icon: Icons.swap_horiz_rounded,
            onTap: () => onMenuSelected(1),
          ),
          WarehouseActionCard(
            title: 'Monitoring Stok',
            subtitle: 'Cek stok realtime dan peringatan stok minimum',
            icon: Icons.inventory_2_rounded,
            onTap: () => onMenuSelected(2),
          ),
          WarehouseActionCard(
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
      boxShadow: AppColors.cardShadow,
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
