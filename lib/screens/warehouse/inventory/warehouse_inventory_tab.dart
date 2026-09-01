import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../tabs/stock_tab.dart';
import 'warehouse_dead_stock_view.dart';
import 'warehouse_fast_slow_moving_view.dart';
import 'warehouse_inventory_valuation_view.dart';
import 'warehouse_stock_aging_view.dart';

class WarehouseInventoryTab extends StatelessWidget {
  const WarehouseInventoryTab({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 5,
    child: ColoredBox(
      color: AppColors.background,
      child: Column(
        children: [
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Container(
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.white,
                unselectedLabelColor: AppColors.slate,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                tabs: const [
                  Tab(text: 'Stok'),
                  Tab(text: 'Valuasi'),
                  Tab(text: 'Aging'),
                  Tab(text: 'Fast / Slow'),
                  Tab(text: 'Dead Stock'),
                ],
              ),
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                StockTab(),
                WarehouseInventoryValuationView(),
                WarehouseStockAgingView(),
                WarehouseFastSlowMovingView(),
                WarehouseDeadStockView(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
