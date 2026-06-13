import 'package:flutter/material.dart';

import 'warehouse_incoming_qc_screen.dart';
import 'warehouse_qc_approval_screen.dart';
import 'warehouse_qc_evidence_screen.dart';
import 'warehouse_production_qc_screen.dart';
import 'warehouse_reject_monitoring_screen.dart';
import 'warehouse_widgets.dart';

class WarehouseQualityTab extends StatelessWidget {
  const WarehouseQualityTab({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: warehousePagePadding,
    children: [
      const WarehouseSectionHeader(
        title: 'Quality Control',
        subtitle: 'Pantau inspeksi, evidence, reject, dan approval QC',
        icon: Icons.fact_check_rounded,
      ),
      warehouseSectionGap,
      WarehouseActionCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WarehouseIncomingQcScreen()),
        ),
        title: 'QC incoming barang',
        subtitle: 'Pantau Quality Inspection barang masuk',
        icon: Icons.move_to_inbox_rounded,
      ),
      WarehouseActionCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WarehouseQcApprovalScreen()),
        ),
        title: 'Approval QC',
        subtitle: 'Review dan submit Quality Inspection draft',
        icon: Icons.approval_outlined,
      ),
      WarehouseActionCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WarehouseQcEvidenceScreen()),
        ),
        title: 'Foto QC evidence',
        subtitle: 'Lampirkan foto bukti ke Quality Inspection',
        icon: Icons.camera_alt_outlined,
      ),
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
    ],
  );
}
