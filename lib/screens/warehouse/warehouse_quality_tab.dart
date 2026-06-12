import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class WarehouseQualityTab extends StatelessWidget {
  const WarehouseQualityTab({super.key});

  static const _features = [
    ('QC incoming barang', Icons.move_to_inbox_rounded),
    ('QC hasil produksi', Icons.precision_manufacturing_outlined),
    ('Reject monitoring', Icons.report_problem_outlined),
    ('Foto QC evidence', Icons.camera_alt_outlined),
    ('Approval QC', Icons.approval_outlined),
  ];

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
    children: [
      const Text(
        'Quality Control',
        style: TextStyle(
          color: AppColors.navy,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Tahap lanjutan setelah operasi gudang stabil.',
        style: TextStyle(color: AppColors.slate),
      ),
      const SizedBox(height: 14),
      ..._features.map(
        (feature) => Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.softGreen,
              foregroundColor: AppColors.primary,
              child: Icon(feature.$2),
            ),
            title: Text(
              feature.$1,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            trailing: const Chip(label: Text('Belum aktif')),
          ),
        ),
      ),
    ],
  );
}
