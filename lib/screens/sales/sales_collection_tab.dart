import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'collection/ar_aging_tab.dart';
import 'collection/outstanding_invoice_tab.dart';
import 'collection/promise_to_pay_tab.dart';

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
            Material(
              color: AppColors.white,
              elevation: 1,
              child: TabBar(
                tabs: const [
                  Tab(text: 'AR Aging'),
                  Tab(text: 'Invoice'),
                  Tab(text: 'Janji Bayar'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  ArAgingTab(),
                  OutstandingInvoiceTab(),
                  PromiseToPayTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
