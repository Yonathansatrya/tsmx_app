import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_state.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';

class StockCheckTab extends StatefulWidget {
  const StockCheckTab({super.key});
  @override
  State<StockCheckTab> createState() => _StockCheckTabState();
}

class _StockCheckTabState extends State<StockCheckTab> {
  static const warehouse = 'Stores - Jakarta';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = state.inventory.where((item) {
      final q = query.toLowerCase();
      return item.warehouseId == warehouse &&
          (q.isEmpty ||
              item.sku.toLowerCase().contains(q) ||
              item.name.toLowerCase().contains(q));
    }).toList();
    return RefreshIndicator(
      onRefresh: () => state.fetchInventoryFromFrappe(
        filters: const [
          ['warehouse', '=', warehouse],
        ],
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Stok realtime Stores - Jakarta',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Chip(label: Text('${items.length} item')),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Cari stok Stores - Jakarta',
              border: OutlineInputBorder(),
            ),
          ),
          if (state.isInventoryLoading) const LinearProgressIndicator(),
          if (state.inventoryError != null) ...[
            ErpErrorBox(message: state.inventoryError!),
            OutlinedButton.icon(
              onPressed: () => state.fetchInventoryFromFrappe(
                filters: const [
                  ['warehouse', '=', warehouse],
                ],
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
          if (items.isEmpty &&
              !state.isInventoryLoading &&
              state.inventoryError == null)
            const ErpEmptyState(title: 'Stok tidak ditemukan')
          else
            ...items.map(
              (item) => Card(
                child: ListTile(
                  title: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('${item.sku} - ${item.warehouseId}'),
                  trailing: Text('${item.quantity}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
