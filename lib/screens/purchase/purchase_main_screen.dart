import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
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
      _PurchaseScrollPage(
        onRefresh: (state) async {
          await Future.wait([
            state.refreshBuyingSummaries(),
            state.refreshPurchaseOrders(),
          ]);
        },
        child: const PurchaseOrderPanel(),
      ),
      _PurchaseScrollPage(
        onRefresh: (state) async {
          await Future.wait([
            state.refreshBuyingSummaries(),
            state.refreshPurchaseReceipts(),
          ]);
        },
        child: const PurchaseReceiptPanel(),
      ),
      _PurchaseScrollPage(
        onRefresh: (state) async {
          await Future.wait([
            state.refreshBuyingSummaries(),
            state.refreshPurchaseInvoices(),
          ]);
        },
        child: const PurchaseInvoicePanel(),
      ),
      _PurchaseScrollPage(
        onRefresh: (state) => Future<void>.value(),
        child: const MaterialRequestPanel(),
      ),
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

class _PurchaseScrollPage extends StatelessWidget {
  final Widget child;
  final Future<void> Function(AppState state) onRefresh;

  const _PurchaseScrollPage({required this.child, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => onRefresh(context.read<AppState>()),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
          children: [child],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_format.dart';
import '../../widgets/erp/erp_filter_tools.dart';
import '../shared/role_main_screen.dart';
import '../tabs/buying/material_request_panel.dart';
import '../tabs/buying/purchase_invoice_panel.dart';
import '../tabs/buying/purchase_order_panel.dart';
import '../tabs/buying/purchase_receipt_panel.dart';

class PurchaseMainScreen extends StatelessWidget {
  const PurchaseMainScreen({super.key});

  @override
  Widget build(BuildContext context) => RoleMainScreen(
    title: 'TMSX PURCHASE',
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
      ]);
    },
    screensBuilder: (onMenuSelected) => [
      PurchaseOverviewTab(onMenuSelected: onMenuSelected),
      const _PurchasePane(child: PurchaseOrderPanel()),
      const _PurchasePane(child: PurchaseReceiptPanel()),
      const _PurchasePane(child: PurchaseInvoicePanel()),
      const _PurchasePane(child: MaterialRequestPanel()),
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
        icon: Icon(Icons.assignment_turned_in_outlined),
        selectedIcon: Icon(Icons.assignment_turned_in_rounded),
        label: 'Request',
      ),
    ],
  );
}

class PurchaseOverviewTab extends StatelessWidget {
  final ValueChanged<int> onMenuSelected;

  const PurchaseOverviewTab({super.key, required this.onMenuSelected});

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
          _HeroCard(
            title: 'Purchase Hari Ini',
            subtitle: 'Pantau PO, penerimaan, invoice, dan request barang.',
            total:
                state.purchaseOrderSummary.totalValue +
                state.purchaseReceiptSummary.totalValue +
                state.purchaseInvoiceSummary.totalValue,
          ),
          const SizedBox(height: 12),
          _OverviewGrid(
            cards: [
              _OverviewCardData(
                title: 'Purchase Order',
                value: state.purchaseOrderSummary.documentCount.toString(),
                subtitle:
                    'Rp ${formatErpCurrency(state.purchaseOrderSummary.totalValue)}',
                icon: Icons.shopping_bag_outlined,
                onTap: () => onMenuSelected(1),
              ),
              _OverviewCardData(
                title: 'Receipt',
                value: state.purchaseReceiptSummary.documentCount.toString(),
                subtitle:
                    'Rp ${formatErpCurrency(state.purchaseReceiptSummary.totalValue)}',
                icon: Icons.move_to_inbox_outlined,
                onTap: () => onMenuSelected(2),
              ),
              _OverviewCardData(
                title: 'Invoice',
                value: state.purchaseInvoiceSummary.documentCount.toString(),
                subtitle:
                    'Rp ${formatErpCurrency(state.purchaseInvoiceSummary.totalValue)}',
                icon: Icons.receipt_long_outlined,
                onTap: () => onMenuSelected(3),
              ),
              _OverviewCardData(
                title: 'Request',
                value: state.materialRequests.length.toString(),
                subtitle: 'Kebutuhan barang',
                icon: Icons.assignment_turned_in_outlined,
                onTap: () => onMenuSelected(4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ActionCard(
            title: 'Mulai dari mana?',
            actions: [
              _ActionItem(
                label: 'Cek PO',
                icon: Icons.shopping_bag_outlined,
                onTap: () => onMenuSelected(1),
              ),
              _ActionItem(
                label: 'Terima Barang',
                icon: Icons.move_to_inbox_outlined,
                onTap: () => onMenuSelected(2),
              ),
              _ActionItem(
                label: 'Request Barang',
                icon: Icons.assignment_add,
                onTap: () => onMenuSelected(4),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
            title: 'Periode Pembelian',
            subtitle: state.buyingPeriodMonth == 0
                ? 'Data mengikuti tahun ini'
                : 'Data mengikuti bulan ini',
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

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double total;

  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.slate,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rp ${formatErpCurrency(total)}',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.slate, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  final List<_OverviewCardData> cards;

  const _OverviewGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.18,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: cards.map((card) => _OverviewCard(data: card)).toList(),
    );
  }
}

class _OverviewCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _OverviewCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _OverviewCard extends StatelessWidget {
  final _OverviewCardData data;

  const _OverviewCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(data.icon, color: AppColors.primary),
            const Spacer(),
            Text(
              data.value,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              data.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.slate, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final List<_ActionItem> actions;

  const _ActionCard({required this.title, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...actions.map(
            (action) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.softGreen,
                foregroundColor: AppColors.primary,
                child: Icon(action.icon),
              ),
              title: Text(
                action.label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: action.onTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}
