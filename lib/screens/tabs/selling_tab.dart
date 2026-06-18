import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/erp/erp_filter_tools.dart';
import '../sales/sales_ui.dart';
import 'selling/sales_order_panel.dart';
import 'selling/delivery_note_panel.dart';
import 'selling/sales_invoice_panel.dart';

class SellingTab extends StatefulWidget {
  final String selectedSegment;
  final ValueChanged<String>? onSegmentChanged;

  const SellingTab({
    super.key,
    required this.selectedSegment,
    this.onSegmentChanged,
  });

  @override
  State<SellingTab> createState() => SellingTabState();
}

class SellingTabState extends State<SellingTab>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  static const _segmentIds = ['so', 'dn', 'si'];

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

    _tabController!.addListener(_handleTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();

      appState.refreshSellingSummaries();

      if (appState.salesOrders.isEmpty) {
        appState.refreshSalesOrders();
      }

      if (appState.deliveryNotes.isEmpty) {
        appState.refreshDeliveryNotes();
      }

      if (appState.salesInvoices.isEmpty) {
        appState.refreshSalesInvoices();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SellingTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final controller = _tabController;
    if (controller == null) return;

    if (oldWidget.selectedSegment == widget.selectedSegment) return;

    final nextIndex = _segmentIds.indexOf(widget.selectedSegment);
    if (nextIndex < 0 || nextIndex >= controller.index) return;

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
      appState.refreshSellingSummaries(),
      switch (_segmentIds[controller.index]) {
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
    final id = _segmentIds[controller.index];

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
                    subtitle: 'Total Rp dan daftar dokumen mengikuti bulan ini',
                    icon: Icons.point_of_sale_rounded,
                    selectedYear: appState.sellingPeriodYear,
                    selectedMonth: appState.sellingPeriodMonth,
                    loading: appState.isOrderSummaryLoading,
                    onChanged: (year, month) {
                      context.read<AppState>().setSellingPeriod(
                        year: year,
                        month: month,
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  SalesPillTabBar(
                    controller: controller,
                    tabs: const [
                      Tab(text: 'Sales Order'),
                      Tab(text: 'Delivery Note'),
                      Tab(text: 'Invoice'),
                    ],
                  ),

                  const SizedBox(height: 14),

                  switch (controller.index) {
                    1 => const DeliveryNotePanel(),
                    2 => const SalesInvoicePanel(),
                    _ => const SalesOrderPanel(),
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
