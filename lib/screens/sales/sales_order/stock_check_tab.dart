import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import '../sales_ui.dart';

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
        padding: SalesUi.compactScreenPadding,
        children: [
          SalesSectionTitle(
            title: 'Stok Realtime',
            subtitle: 'Gudang Stores - Jakarta',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${items.length} item',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SalesUi.gap(12),
          SalesInfoCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Cari item atau kode barang',
                hintText: 'Contoh: SPF-JKT-023',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          SalesUi.gap(12),
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
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SalesInfoCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${item.sku} - ${item.warehouseId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.slate,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.softGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
