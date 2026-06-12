import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'warehouse_operation_history_screen.dart';
import 'warehouse_stock_opname_screen.dart';
import 'warehouse_stock_entry_screen.dart';

class WarehouseOperationsTab extends StatelessWidget {
  const WarehouseOperationsTab({super.key});

  static const _features = [
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
      Card(
        child: ListTile(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WarehouseOperationHistoryScreen(),
            ),
          ),
          leading: const CircleAvatar(
            backgroundColor: AppColors.softGreen,
            foregroundColor: AppColors.primary,
            child: Icon(Icons.history_rounded),
          ),
          title: const Text(
            'Riwayat operasi gudang',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: const Text('Periksa transaksi dan status draft terbaru'),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        ),
      ),
      _operationCard(
        context,
        operation: WarehouseOperation.transfer,
        subtitle: 'Pindahkan beberapa item antar gudang',
      ),
      _operationCard(
        context,
        operation: WarehouseOperation.receive,
        subtitle: 'Catat barang yang masuk ke gudang',
      ),
      _operationCard(
        context,
        operation: WarehouseOperation.issue,
        subtitle: 'Catat barang yang keluar dari gudang',
      ),
      Card(
        child: ListTile(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WarehouseStockOpnameScreen(),
            ),
          ),
          leading: const CircleAvatar(
            backgroundColor: AppColors.softGreen,
            foregroundColor: AppColors.primary,
            child: Icon(Icons.inventory_outlined),
          ),
          title: const Text(
            'Stock opname mobile',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: const Text(
            'Hitung stok fisik dan simpan selisih sebagai draft',
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        ),
      ),
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

  Widget _operationCard(
    BuildContext context, {
    required WarehouseOperation operation,
    required String subtitle,
  }) => Card(
    child: ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WarehouseStockEntryScreen(operation: operation),
        ),
      ),
      leading: CircleAvatar(
        backgroundColor: AppColors.softGreen,
        foregroundColor: AppColors.primary,
        child: Icon(operation.icon),
      ),
      title: Text(
        operation.title,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
    ),
  );
}
