import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../create_sales_order_screen.dart';
import 'customer_insight_tab.dart';
import 'sales_order_list_tab.dart';
import 'stock_check_tab.dart';

class SalesOrderScreen extends StatelessWidget {
  const SalesOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const TabBar(
          tabs: [
            Tab(text: 'Sales Order'),
            Tab(text: 'Cek Stok'),
            Tab(text: 'Customer Check'),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateSalesOrderScreen()),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Sales Order'),
        ),
        body: const TabBarView(
          children: [
            SalesOrderListTab(),
            StockCheckTab(),
            CustomerInsightTab(),
          ],
        ),
      ),
    );
  }
}
