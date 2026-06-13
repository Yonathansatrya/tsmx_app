import 'package:flutter/material.dart';

import 'warehouse_production_qc_screen.dart';
import 'warehouse_reject_monitoring_screen.dart';
import 'warehouse_widgets.dart';

class WarehouseQualityTab extends StatelessWidget {
  const WarehouseQualityTab({super.key});

  static const _features = [
    ('QC incoming barang', Icons.move_to_inbox_rounded),
    ('Foto QC evidence', Icons.camera_alt_outlined),
    ('Approval QC', Icons.approval_outlined),
  ];

  @override
  Widget build(BuildContext context) => ListView(
    padding: warehousePagePadding,
    children: [
      const WarehouseSectionHeader(
        title: 'Quality Control',
        subtitle: 'Tahap lanjutan setelah operasi gudang stabil',
        icon: Icons.fact_check_rounded,
      ),
      warehouseSectionGap,
      WarehouseActionCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const WarehouseProductionQcScreen(),
          ),
        ),
        title: 'QC hasil produksi',
        subtitle: 'Pantau Quality Inspection selama proses produksi',
        icon: Icons.precision_manufacturing_outlined,
      ),
      WarehouseActionCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const WarehouseRejectMonitoringScreen(),
          ),
        ),
        title: 'Reject monitoring',
        subtitle: 'Pantau hasil Quality Inspection yang ditolak',
        icon: Icons.report_problem_outlined,
      ),
      ..._features.map(
        (feature) => WarehouseActionCard(
          title: feature.$1,
          subtitle: 'Akan tersedia pada tahap Quality Control',
          icon: feature.$2,
          status: 'Belum aktif',
        ),
      ),
    ],
  );
}
