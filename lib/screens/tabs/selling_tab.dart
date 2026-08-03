import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/erp/erp_filter_tools.dart';
import '../sales/sales_ui.dart';
import 'selling/sales_order_panel.dart';
import 'selling/delivery_note_panel.dart';
import 'selling/sales_invoice_panel.dart';

const _defaultSellingSegmentIds = ['so', 'dn', 'si'];

class SellingTab extends StatefulWidget {
  final String selectedSegment;
  final List<String> allowedSegments;
  final ValueChanged<String>? onSegmentChanged;

  const SellingTab({
    super.key,
    required this.selectedSegment,
    this.allowedSegments = _defaultSellingSegmentIds,
    this.onSegmentChanged,
  });

  @override
  State<SellingTab> createState() => SellingTabState();
}

class SellingTabState extends State<SellingTab>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  List<String> get _allowedSegments {
    final allowed = widget.allowedSegments
        .where(_defaultSellingSegmentIds.contains)
        .toSet()
        .toList(growable: false);
    return allowed.isEmpty ? const ['so'] : allowed;
  }

  String get _activeDocumentType {
    final controller = _tabController;
    final index = controller?.index ?? _initialIndex;
    return switch (_allowedSegments[index]) {
      'dn' => 'Delivery Note',
      'si' => 'Sales Invoice',
      _ => 'Sales Order',
    };
  }

  int get _initialIndex {
    final index = _allowedSegments.indexOf(widget.selectedSegment);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: _allowedSegments.length,
      vsync: this,
      initialIndex: _initialIndex,
    );

    _tabController!.addListener(_handleTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();

      appState.loadSellingFilterOptions();
      appState.refreshSellingSummaries(documentType: _activeDocumentType);
      _ensureActiveDocumentLoaded(appState);
    });
  }

  @override
  void didUpdateWidget(covariant SellingTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final controller = _tabController;
    if (controller == null) return;

    if (oldWidget.selectedSegment == widget.selectedSegment) return;

    final nextIndex = _allowedSegments.indexOf(widget.selectedSegment);
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

    final id = _allowedSegments[controller.index];

    widget.onSegmentChanged?.call(id);

    final appState = context.read<AppState>();
    appState.refreshSellingSummaries(documentType: _activeDocumentType);
    _ensureActiveDocumentLoaded(appState);
  }

  void _ensureActiveDocumentLoaded(AppState appState) {
    final controller = _tabController;
    final id = _allowedSegments[controller?.index ?? _initialIndex];
    switch (id) {
      case 'dn':
        if (appState.deliveryNotes.isEmpty) {
          appState.refreshDeliveryNotes();
        }
        break;

      case 'si':
        if (appState.salesInvoices.isEmpty) {
          appState.refreshSalesInvoices();
        }
        break;

      case 'so':
      default:
        if (appState.salesOrders.isEmpty) {
          appState.refreshSalesOrders();
        }
        break;
    }
  }

  Future<void> refreshCurrent() async {
    final controller = _tabController;
    if (controller == null) return;

    final appState = context.read<AppState>();

    await Future.wait([
      appState.refreshSellingSummaries(
        forceRemote: true,
        documentType: _activeDocumentType,
      ),
      switch (_allowedSegments[controller.index]) {
        'dn' => appState.refreshDeliveryNotes(),
        'si' => appState.refreshSalesInvoices(),
        _ => appState.refreshSalesOrders(),
      },
    ]);
  }

  void _handleLoadMore() {
    final controller = _tabController;
    if (controller == null) return;

    final appState = context.read<AppState>();
    final id = _allowedSegments[controller.index];

    switch (id) {
      case 'dn':
        appState.loadMoreDeliveryNotes();
        break;

      case 'si':
        appState.loadMoreSalesInvoices();
        break;

      case 'so':
      default:
        appState.loadMoreSalesOrders();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final salesGroupFilter =
        appState.sellingCustomerTypeFilter == 'all' ||
            appState.sellingSalesGroups.contains(
              appState.sellingCustomerTypeFilter,
            )
        ? appState.sellingCustomerTypeFilter
        : 'all';
    final salesGroupOptions = <String, String>{
      'all': 'All',
      for (final group in appState.sellingSalesGroups) group: group,
    };

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
                    title: 'Periode Selling',
                    subtitle: appState.sellingPeriodMonth == 0
                        ? 'Total Rp dan daftar dokumen mengikuti tahun ini'
                        : 'Total Rp dan daftar dokumen mengikuti bulan ini',
                    icon: Icons.point_of_sale_rounded,
                    selectedYear: appState.sellingPeriodYear,
                    selectedMonth: appState.sellingPeriodMonth,
                    loading: false,
                    showLoadingIndicator: appState.isOrderSummaryLoading,
                    companyOptions: appState.sellingCompanies,
                    selectedCompany: appState.sellingCompanyFilter,
                    selectedCustomerType:
                        appState.mobileAccess.shouldScopeSalesData
                        ? 'all'
                        : salesGroupFilter,
                    partnerTypeLabel: appState.mobileAccess.shouldScopeSalesData
                        ? ''
                        : 'Sales Group',
                    partnerTypeIcon: Icons.account_tree_rounded,
                    partnerTypeOptions:
                        appState.mobileAccess.shouldScopeSalesData
                        ? const {'all': 'All'}
                        : salesGroupOptions,
                    onChanged: (year, month) {
                      context.read<AppState>().setSellingPeriod(
                        year: year,
                        month: month,
                        documentType: _activeDocumentType,
                      );
                    },
                    onCompanyChanged: (company) {
                      context.read<AppState>().setSellingPeriod(
                        year: appState.sellingPeriodYear,
                        month: appState.sellingPeriodMonth,
                        company: company,
                        documentType: _activeDocumentType,
                      );
                    },
                    onCustomerTypeChanged:
                        appState.mobileAccess.shouldScopeSalesData
                        ? null
                        : (customerType) {
                            context.read<AppState>().setSellingPeriod(
                              year: appState.sellingPeriodYear,
                              month: appState.sellingPeriodMonth,
                              customerType: customerType,
                              documentType: _activeDocumentType,
                            );
                          },
                  ),

                  const SizedBox(height: 12),

                  SalesPillTabBar(
                    controller: controller,
                    tabs: [
                      for (final segment in _allowedSegments)
                        Tab(text: _segmentLabel(segment)),
                    ],
                  ),

                  const SizedBox(height: 14),

                  switch (controller.index) {
                    _ => _segmentPanel(_allowedSegments[controller.index]),
                  },
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _segmentLabel(String segment) => switch (segment) {
    'dn' => 'Delivery Note',
    'si' => 'Invoice',
    _ => 'Sales Order',
  };

  Widget _segmentPanel(String segment) => switch (segment) {
    'dn' => const DeliveryNotePanel(),
    'si' => const SalesInvoicePanel(),
    _ => const SalesOrderPanel(),
  };
}
