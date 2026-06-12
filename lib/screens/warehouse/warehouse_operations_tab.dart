import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class WarehouseOperationsTab extends StatelessWidget {
  const WarehouseOperationsTab({super.key});

  static const _features = [
    ('Transfer antar gudang', Icons.swap_horiz_rounded, 'Mudah'),
    ('Goods Receive', Icons.move_to_inbox_rounded, 'Mudah'),
    ('Goods Issue', Icons.outbox_rounded, 'Mudah'),
    ('Stock opname mobile', Icons.inventory_outlined, 'Menengah'),
    ('Barcode / QR Scan', Icons.qr_code_scanner_rounded, 'Menengah'),
    ('Batch & Serial Number tracking', Icons.numbers_rounded, 'Menengah'),
  ];

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
    children: [
      const Text(
        'Warehouse Operation',
        style: TextStyle(
          color: AppColors.navy,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Kerjakan transaksi gudang secara bertahap.',
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
            subtitle: Text('Prioritas ${feature.$3}'),
            trailing: const Chip(label: Text('Belum aktif')),
          ),
        ),
      ),
    ],
  );
}
