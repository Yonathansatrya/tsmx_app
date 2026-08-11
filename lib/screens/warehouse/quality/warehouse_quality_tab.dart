import 'package:flutter/material.dart';

import 'warehouse_incoming_qc_screen.dart';
import 'warehouse_qc_approval_screen.dart';
import 'warehouse_qc_evidence_screen.dart';
import 'warehouse_production_qc_screen.dart';
import 'warehouse_reject_monitoring_screen.dart';
import '../shared/warehouse_widgets.dart';

class WarehouseQualityTab extends StatelessWidget {
  const WarehouseQualityTab({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _WarehouseQualityAction(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WarehouseIncomingQcScreen()),
        ),
        title: 'Incoming QC',
        subtitle: 'Inspection barang masuk',
        icon: Icons.move_to_inbox_rounded,
        color: warehouseGreen,
      ),
      _WarehouseQualityAction(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const WarehouseProductionQcScreen(),
          ),
        ),
        title: 'Production QC',
        subtitle: 'Hasil dan proses produksi',
        icon: Icons.precision_manufacturing_outlined,
        color: warehouseBlue,
      ),
      _WarehouseQualityAction(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const WarehouseRejectMonitoringScreen(),
          ),
        ),
        title: 'Reject',
        subtitle: 'Monitoring item ditolak',
        icon: Icons.report_problem_outlined,
        color: warehouseOrange,
      ),
      _WarehouseQualityAction(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WarehouseQcEvidenceScreen()),
        ),
        title: 'Evidence',
        subtitle: 'Lampiran foto QC',
        icon: Icons.camera_alt_outlined,
        color: warehouseCyan,
      ),
      _WarehouseQualityAction(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WarehouseQcApprovalScreen()),
        ),
        title: 'Approval QC',
        subtitle: 'Review dan submit draft',
        icon: Icons.approval_outlined,
        color: warehousePurple,
      ),
    ];

    return ListView(
      padding: warehousePagePadding,
      children: [
        const WarehouseSectionHeader(
          title: 'Quality Control',
          subtitle: 'Inspection, evidence, reject, dan approval QC',
          icon: Icons.fact_check_rounded,
        ),
        warehouseSectionGap,
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 14,
          childAspectRatio: 0.86,
          children: actions
              .map(
                (action) => WarehouseActionGridCard(
                  onTap: action.onTap,
                  icon: action.icon,
                  title: action.title,
                  subtitle: action.subtitle,
                  color: action.color,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _WarehouseQualityAction {
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _WarehouseQualityAction({
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
