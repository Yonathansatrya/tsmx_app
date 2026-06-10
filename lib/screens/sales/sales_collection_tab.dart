import 'package:flutter/material.dart';

import 'collection/ar_aging_tab.dart';
import 'collection/outstanding_invoice_tab.dart';
import 'collection/promise_to_pay_tab.dart';

class SalesCollectionTab extends StatelessWidget {
  const SalesCollectionTab({super.key});

  @override
  Widget build(BuildContext context) => const DefaultTabController(
    length: 3,
    child: Column(
      children: [
        Material(
          child: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'AR Aging & Rank'),
              Tab(text: 'Overdue & Invoices'),
              Tab(text: 'Janji Bayar'),
            ],
          ),
        ),
        Expanded(
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
  );
}
