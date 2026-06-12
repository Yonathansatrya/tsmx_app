import 'package:flutter/material.dart';

import 'warehouse_operation_history_screen.dart';
import 'warehouse_stock_opname_screen.dart';
import 'warehouse_stock_entry_screen.dart';
import 'warehouse_widgets.dart';

class WarehouseOperationsTab extends StatelessWidget {
  const WarehouseOperationsTab({super.key});

  static const _features = [
    ('Barcode / QR Scan', Icons.qr_code_scanner_rounded, 'Menengah'),
    ('Batch & Serial Number tracking', Icons.numbers_rounded, 'Menengah'),
  ];

  @override
  Widget build(BuildContext context) => ListView(
    padding: warehousePagePadding,
    children: [
      const WarehouseSectionHeader(
        title: 'Warehouse Operation',
        subtitle: 'Pilih aktivitas gudang yang ingin dikerjakan',
        icon: Icons.swap_horiz_rounded,
      ),
      warehouseSectionGap,
      WarehouseActionCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const WarehouseOperationHistoryScreen(),
          ),
        ),
        icon: Icons.history_rounded,
        title: 'Riwayat operasi gudang',
        subtitle: 'Periksa transaksi dan status draft terbaru',
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
      WarehouseActionCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WarehouseStockOpnameScreen()),
        ),
        icon: Icons.inventory_outlined,
        title: 'Stock opname mobile',
        subtitle: 'Hitung stok fisik dan simpan selisih sebagai draft',
      ),
      ..._features.map(
        (feature) => WarehouseActionCard(
          icon: feature.$2,
          title: feature.$1,
          subtitle: 'Prioritas ${feature.$3}',
          status: 'Belum aktif',
        ),
      ),
    ],
  );

  Widget _operationCard(
    BuildContext context, {
    required WarehouseOperation operation,
    required String subtitle,
  }) => WarehouseActionCard(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WarehouseStockEntryScreen(operation: operation),
      ),
    ),
    icon: operation.icon,
    title: operation.title,
    subtitle: subtitle,
  );
}
