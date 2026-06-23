import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/erp/erp_filter_tools.dart';
import '../sales/sales_ui.dart';
import 'buying/purchase_order_panel.dart';
import 'buying/purchase_receipt_panel.dart';
import 'buying/purchase_invoice_panel.dart';

class BuyingTab extends StatefulWidget {
  final String selectedSegment;
  final ValueChanged<String>? onSegmentChanged;

  const BuyingTab({
    super.key,
    required this.selectedSegment,
    this.onSegmentChanged,
  });

  @override
  State<BuyingTab> createState() => BuyingTabState();
}

class BuyingTabState extends State<BuyingTab>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  static const _segmentIds = ['po', 'pr', 'pi'];

  int get _initialIndex {
    final index = _segmentIds.indexOf(widget.selectedSegment);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: _segmentIds.length,
      vsync: this,
      initialIndex: _initialIndex,
    );

    _tabController?.addListener(_handleTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();

      appState.loadBuyingFilterOptions();
      appState.refreshBuyingSummaries();

      if (appState.purchaseOrders.isEmpty) {
        appState.refreshPurchaseOrders();
      }

      if (appState.purchaseReceipts.isEmpty) {
        appState.refreshPurchaseReceipts();
      }

      if (appState.purchaseInvoices.isEmpty) {
        appState.refreshPurchaseInvoices();
      }
    });
  }

  @override
  void didUpdateWidget(covariant BuyingTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final controller = _tabController;
    if (controller == null) return;

    if (oldWidget.selectedSegment == widget.selectedSegment) return;

    final nextIndex = _segmentIds.indexOf(widget.selectedSegment);
    if (nextIndex < 0 || nextIndex == controller.index) return;

    controller.animateTo(nextIndex);
  }

  @override
  void dispose() {
    final controller = _tabController;

    if (controller != null) {
      controller.removeListener(_handleTabChanged);
      controller.dispose();
    }

    super.dispose();
  }

  void _handleTabChanged() {
    final controller = _tabController;
    if (controller == null) return;
    if (controller.indexIsChanging) return;

    final id = _segmentIds[controller.index];

    widget.onSegmentChanged?.call(id);

    final appState = context.read<AppState>();

    switch (id) {
      case 'pr':
        if (appState.purchaseReceipts.isEmpty) {
          appState.refreshPurchaseReceipts();
        }
        break;

      case 'pi':
        if (appState.purchaseInvoices.isEmpty) {
          appState.refreshPurchaseInvoices();
        }
        break;

      case 'po':
      default:
        if (appState.purchaseOrders.isEmpty) {
          appState.refreshPurchaseOrders();
        }
        break;
    }
  }

  Future<void> refreshCurrent() async {
    final controller = _tabController;
    if (controller == null) return;

    final appState = context.read<AppState>();

    await Future.wait([
      appState.refreshBuyingSummaries(),
      switch (_segmentIds[controller.index]) {
        'pr' => appState.refreshPurchaseReceipts(),
        'pi' => appState.refreshPurchaseInvoices(),
        _ => appState.refreshPurchaseOrders(),
      },
    ]);
  }

  void _handleLoadMore() {
    final controller = _tabController;
    if (controller == null) return;

    final appState = context.read<AppState>();
    final id = _segmentIds[controller.index];

    switch (id) {
      case 'pr':
        appState.loadMorePurchaseReceipts();
        break;

      case 'pi':
        appState.loadMorePurchaseInvoices();
        break;

      case 'po':
      default:
        appState.loadMorePurchaseOrders();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final controller = _tabController;

    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: refreshCurrent,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.extentAfter > 320) return false;
            _handleLoadMore();
            return false;
          },
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  ErpPeriodFilterCard(
                    title: 'Periode Pembelian',
                    subtitle: appState.buyingPeriodMonth == 0
                        ? 'PO, receipt, invoice, dan total Rp mengikuti tahun ini'
                        : 'PO, receipt, invoice, dan total Rp mengikuti bulan ini',
                    icon: Icons.shopping_bag_rounded,
                    selectedYear: appState.buyingPeriodYear,
                    selectedMonth: appState.buyingPeriodMonth,
                    loading: appState.isOrderSummaryLoading,
                    companyOptions: appState.buyingCompanies,
                    selectedCompany: appState.buyingCompanyFilter,
                    onCompanyChanged: (company) {
                      context.read<AppState>().setBuyingPeriod(
                        year: appState.buyingPeriodYear,
                        month: appState.buyingPeriodMonth,
                        company: company,
                      );
                    },
                    selectedCustomerType: appState.buyingSupplierTypeFilter,
                    onCustomerTypeChanged: (supplierType) {
                      context.read<AppState>().setBuyingPeriod(
                        year: appState.buyingPeriodYear,
                        month: appState.buyingPeriodMonth,
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

                  const SizedBox(height: 12),

                  SalesPillTabBar(
                    controller: controller,
                    tabs: const [
                      Tab(text: 'Purchase Order'),
                      Tab(text: 'Receipt'),
                      Tab(text: 'Invoice'),
                    ],
                  ),

                  const SizedBox(height: 14),

                  switch (controller.index) {
                    1 => const PurchaseReceiptPanel(),
                    2 => const PurchaseInvoicePanel(),
                    _ => const PurchaseOrderPanel(),
                  },
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
