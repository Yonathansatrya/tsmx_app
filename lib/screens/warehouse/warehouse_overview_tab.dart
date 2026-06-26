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
          _WarehouseHeroCard(
            warehouses: state.warehouses.length,
            lowStock: lowStock,
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

class _WarehouseHeroCard extends StatelessWidget {
  final int warehouses;
  final int lowStock;

  const _WarehouseHeroCard({required this.warehouses, required this.lowStock});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.warehouse_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Warehouse Workspace',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lowStock > 0
                      ? '$lowStock item perlu perhatian stok'
                      : 'Stok dan aktivitas gudang siap dipantau',
                  style: TextStyle(
                    color: AppColors.slate,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$warehouses',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const Text(
                  'Gudang',
                  style: TextStyle(
                    color: AppColors.slate,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
