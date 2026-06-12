import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../tabs/stock_tab.dart';
import 'warehouse_inventory_valuation_view.dart';
import 'warehouse_stock_aging_view.dart';

class WarehouseInventoryTab extends StatelessWidget {
  const WarehouseInventoryTab({super.key});

  @override
  Widget build(BuildContext context) => const DefaultTabController(
    length: 3,
    child: ColoredBox(
      color: AppColors.background,
      child: Column(
        children: [
          Material(
            color: AppColors.white,
            elevation: 1,
            child: TabBar(
              tabs: [
                Tab(text: 'Stok Realtime'),
                Tab(text: 'Valuasi'),
                Tab(text: 'Aging'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                StockTab(),
                WarehouseInventoryValuationView(),
                WarehouseStockAgingView(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
