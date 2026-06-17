import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'sales_order/create_sales_order_screen.dart';
import 'sales_order/customer_insight_tab.dart';
import 'sales_order/sales_order_list_tab.dart';
import 'sales_order/stock_check_tab.dart';

class SalesOrderTab extends StatelessWidget {
  const SalesOrderTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: ColoredBox(
        color: AppColors.background,
        child: Stack(
          children: [
            const Column(
              children: [
                SizedBox(height: 6),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    color: AppColors.white,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    child: TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelPadding: EdgeInsets.symmetric(horizontal: 4),
                      tabs: [
                        Tab(text: 'Sales Order'),
                        Tab(text: 'Cek Stok'),
                        Tab(text: 'Cek Customer'),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 2),
                Expanded(
                  child: TabBarView(
                    children: [
                      SalesOrderListTab(),
                      StockCheckTab(),
                      CustomerInsightTab(),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 28,
              child: FloatingActionButton.extended(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                elevation: 3,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateSalesOrderScreen(),
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Buat Sales Order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
