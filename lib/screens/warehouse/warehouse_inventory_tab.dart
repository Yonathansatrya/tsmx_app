import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../tabs/stock_tab.dart';
import 'warehouse_inventory_valuation_view.dart';

class WarehouseInventoryTab extends StatefulWidget {
  const WarehouseInventoryTab({super.key});

  @override
  State<WarehouseInventoryTab> createState() => _WarehouseInventoryTabState();
}

class _WarehouseInventoryTabState extends State<WarehouseInventoryTab> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        color: AppColors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.inventory_2_outlined),
              label: Text('Stok Realtime'),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(Icons.payments_outlined),
              label: Text('Valuasi'),
            ),
          ],
          selected: {_selected},
          showSelectedIcon: false,
          onSelectionChanged: (value) =>
              setState(() => _selected = value.first),
        ),
      ),
      Expanded(
        child: IndexedStack(
          index: _selected,
          children: const [StockTab(), WarehouseInventoryValuationView()],
        ),
      ),
    ],
  );
}
