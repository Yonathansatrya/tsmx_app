import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/erp/erp_filter_tools.dart';
import '../shared/role_main_screen.dart';
import '../tabs/buying/purchase_invoice_panel.dart';
import '../tabs/buying/purchase_order_panel.dart';
import '../tabs/buying/purchase_receipt_panel.dart';
import '../todo/todo_list.dart';
import 'material_request/create_material_request_screen.dart';
import 'material_request/material_request_panel.dart';
import 'purchase_invoice/create_purchase_invoice_screen.dart';
import 'purchase_order/create_purchase_order_screen.dart';
import 'purchase_overview_tab.dart';
import 'purchase_receipt/create_purchase_receipt_screen.dart';

class PurchaseMainScreen extends StatelessWidget {
  const PurchaseMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleMainScreen(
      title: 'TMSX Hub Purchase',
      fallbackUsername: 'Purchase',
      onInitialize: (state) async {
        await state.loadBuyingFilterOptions();
        await Future.wait([
          state.refreshBuyingSummaries(),
          state.refreshPurchaseOrders(),
          state.refreshPurchaseReceipts(),
          state.refreshPurchaseInvoices(),
          state.refreshMaterialRequests(),
          state.refreshInventory(),
          state.fetchApprovalTodos(),
        ]);
      },
      screensBuilder: (onMenuSelected) => [
        PurchaseOverviewTab(onMenuSelected: onMenuSelected),
        const _PurchasePane(child: PurchaseOrderPanel()),
        const _PurchasePane(child: PurchaseReceiptPanel()),
        const _PurchasePane(child: PurchaseInvoicePanel()),
        const _PurchasePane(child: MaterialRequestPanel()),
        const SalesOrderApprovalScreen(
          embedded: true,
          title: 'Approval Pembelian',
          doctypeFilter: AppState.purchaseApprovalDoctypes,
          showHistoryTab: false,
        ),
      ],
      floatingActionButtonBuilder: _buildPurchaseFab,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        const NavigationDestination(
          icon: Icon(Icons.shopping_bag_outlined),
          selectedIcon: Icon(Icons.shopping_bag_rounded),
          label: 'PO',
        ),
        const NavigationDestination(
          icon: Icon(Icons.move_to_inbox_outlined),
          selectedIcon: Icon(Icons.move_to_inbox_rounded),
          label: 'Receipt',
        ),
        const NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: 'Invoice',
        ),
        const NavigationDestination(
          icon: Icon(Icons.assignment_turned_in_outlined),
          selectedIcon: Icon(Icons.assignment_turned_in_rounded),
          label: 'Request',
        ),
      ],
    );
  }
}

Widget? _buildPurchaseFab(BuildContext context, int currentIndex) {
  if (currentIndex == 0 || currentIndex >= 5) return null;
  return FloatingActionButton.extended(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.white,
    onPressed: () => _openPurchaseCreate(context, currentIndex),
    icon: Icon(switch (currentIndex) {
      2 => Icons.move_to_inbox_outlined,
      3 => Icons.receipt_long_outlined,
      4 => Icons.assignment_add,
      _ => Icons.add_shopping_cart_rounded,
    }),
    label: Text(switch (currentIndex) {
      2 => 'Terima Barang',
      3 => 'Buat Invoice',
      4 => 'Buat Request',
      _ => 'Buat PO',
    }),
  );
}

Future<void> _openPurchaseCreate(BuildContext context, int currentIndex) async {
  final route = switch (currentIndex) {
    2 => MaterialPageRoute<void>(
      builder: (_) => const CreatePurchaseReceiptScreen(),
    ),
    3 => MaterialPageRoute<void>(
      builder: (_) => const CreatePurchaseInvoiceScreen(),
    ),
    4 => MaterialPageRoute<void>(
      builder: (_) => const CreateMaterialRequestScreen(),
    ),
    _ => MaterialPageRoute<void>(
      builder: (_) => const CreatePurchaseOrderScreen(),
    ),
  };

  await Navigator.of(context).push(route);
  if (!context.mounted) return;

  final state = context.read<AppState>();
  await Future.wait([
    state.refreshBuyingSummaries(),
    switch (currentIndex) {
      2 => state.refreshPurchaseReceipts(),
      3 => state.refreshPurchaseInvoices(),
      4 => state.refreshMaterialRequests(),
      _ => state.refreshPurchaseOrders(),
    },
  ]);
}

class _PurchasePane extends StatelessWidget {
  final Widget child;

  const _PurchasePane({required this.child});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await Future.wait([
          state.refreshBuyingSummaries(),
          state.refreshPurchaseOrders(),
          state.refreshPurchaseReceipts(),
          state.refreshPurchaseInvoices(),
          state.refreshMaterialRequests(),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          ErpPeriodFilterCard(
            title: 'Filter Pembelian',
            subtitle: state.buyingPeriodMonth == 0
                ? 'Ringkasan dan daftar dokumen mengikuti tahun ini'
                : 'Ringkasan dan daftar dokumen mengikuti bulan ini',
            icon: Icons.shopping_bag_rounded,
            selectedYear: state.buyingPeriodYear,
            selectedMonth: state.buyingPeriodMonth,
            loading: state.isOrderSummaryLoading,
            companyOptions: state.buyingCompanies,
            selectedCompany: state.buyingCompanyFilter,
            onCompanyChanged: (company) {
              context.read<AppState>().setBuyingPeriod(
                year: state.buyingPeriodYear,
                month: state.buyingPeriodMonth,
                company: company,
              );
            },
            selectedCustomerType: state.buyingSupplierTypeFilter,
            onCustomerTypeChanged: (supplierType) {
              context.read<AppState>().setBuyingPeriod(
                year: state.buyingPeriodYear,
                month: state.buyingPeriodMonth,
                supplierType: supplierType,
              );
            },
            partnerTypeLabel: 'Supplier',
            partnerTypeIcon: Icons.storefront_rounded,
            onChanged: (year, month) {
              context.read<AppState>().setBuyingPeriod(
                year: year,
                month: month,
              );
            },
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
