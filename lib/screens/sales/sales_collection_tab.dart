import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'collection/ar_aging_tab.dart';
import 'collection/outstanding_invoice_tab.dart';
import 'collection/customer_payment_schedule_tab.dart';
import 'sales_ui.dart';

class SalesCollectionTab extends StatelessWidget {
  const SalesCollectionTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: ColoredBox(
        color: AppColors.background,
        child: Column(
          children: [
            const SalesPillTabBar(
              tabs: [
                Tab(text: 'AR Aging'),
                Tab(text: 'Invoice'),
                Tab(text: 'Janji Bayar'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  ArAgingTab(),
                  OutstandingInvoiceTab(),
                  CustomerPaymentScheduleTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
