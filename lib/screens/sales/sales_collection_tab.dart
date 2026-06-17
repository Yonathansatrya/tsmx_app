import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'collection/ar_aging_tab.dart';
import 'collection/outstanding_invoice_tab.dart';
import 'collection/customer_payment_schedule_tab.dart';

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
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                child: const TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelPadding: EdgeInsets.symmetric(horizontal: 4),
                  tabs: [
                    Tab(text: 'AR Aging'),
                    Tab(text: 'Invoice'),
                    Tab(text: 'Janji Bayar'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
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
