import 'package:flutter/material.dart';

import 'ar_aging_tab.dart';
import 'outstanding_invoice_tab.dart';
import 'promise_to_pay_tab.dart';

class CollectionDashboardScreen extends StatelessWidget {
  const CollectionDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => const DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: TabBar(
        isScrollable: true,
        tabs: [
          Tab(text: 'AR Aging & Rank'),
          Tab(text: 'Overdue & Invoices'),
          Tab(text: 'Janji Bayar'),
        ],
      ),
      body: TabBarView(
        children: [ArAgingTab(), OutstandingInvoiceTab(), PromiseToPayTab()],
      ),
    ),
  );
}
