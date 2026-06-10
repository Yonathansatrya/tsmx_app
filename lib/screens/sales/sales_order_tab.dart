import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../create_sales_order_screen.dart';
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
                Material(
                  color: AppColors.white,
                  child: TabBar(
                    tabs: [
                      Tab(text: 'Sales Order'),
                      Tab(text: 'Cek Stok'),
                      Tab(text: 'Cek Customer'),
                    ],
                  ),
                ),
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
              bottom: 16,
              child: FloatingActionButton.extended(
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
