import 'package:flutter/material.dart';

import '../shared/role_main_screen.dart';
import '../tabs/buying/purchase_invoice_panel.dart';
import '../tabs/buying/purchase_order_panel.dart';
import '../tabs/buying/purchase_receipt_panel.dart';
import 'material_request/material_request_panel.dart';
import 'purchase_overview_tab.dart';

class PurchaseMainScreen extends StatelessWidget {
  const PurchaseMainScreen({super.key});

  @override
  Widget build(BuildContext context) => RoleMainScreen(
    title: 'TMSX PURCHASE',
    fallbackUsername: 'Purchase',
    onInitialize: (state) async {
      await Future.wait([
        state.refreshBuyingSummaries(),
        state.refreshPurchaseOrders(),
        state.refreshPurchaseReceipts(),
        state.refreshPurchaseInvoices(),
        state.refreshInventory(),
      ]);
    },
    screensBuilder: (onMenuSelected) => [
      PurchaseOverviewTab(onMenuSelected: onMenuSelected),
      const PurchaseOrderPanel(),
      const PurchaseReceiptPanel(),
      const PurchaseInvoicePanel(),
      const MaterialRequestPanel(),
    ],
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Beranda',
      ),
      NavigationDestination(
        icon: Icon(Icons.shopping_bag_outlined),
        selectedIcon: Icon(Icons.shopping_bag_rounded),
        label: 'PO',
      ),
      NavigationDestination(
        icon: Icon(Icons.move_to_inbox_outlined),
        selectedIcon: Icon(Icons.move_to_inbox_rounded),
        label: 'Receipt',
      ),
      NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long_rounded),
        label: 'Invoice',
      ),
      NavigationDestination(
        icon: Icon(Icons.assignment_outlined),
        selectedIcon: Icon(Icons.assignment_rounded),
        label: 'Request',
      ),
    ],
  );
}
