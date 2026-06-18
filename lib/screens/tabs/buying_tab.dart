import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/erp/erp_filter_tools.dart';
import '../../widgets/erp/erp_segment_bar.dart';
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

class BuyingTabState extends State<BuyingTab> {
  static const segments = [
    ErpSegmentOption(id: 'po', label: 'Purchase Order'),
    ErpSegmentOption(id: 'pr', label: 'Receipt'),
    ErpSegmentOption(id: 'pi', label: 'Invoice'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      appState.refreshBuyingSummaries();
      if (appState.purchaseOrders.isEmpty) appState.refreshPurchaseOrders();
      if (appState.purchaseReceipts.isEmpty) {
        appState.refreshPurchaseReceipts();
      }
      if (appState.purchaseInvoices.isEmpty) {
        appState.refreshPurchaseInvoices();
      }
    });
  }

  Future<void> refreshCurrent() async {
    final appState = context.read<AppState>();
    await Future.wait([
      appState.refreshBuyingSummaries(),
      switch (widget.selectedSegment) {
        'pr' => appState.refreshPurchaseReceipts(),
        'pi' => appState.refreshPurchaseInvoices(),
        _ => appState.refreshPurchaseOrders(),
      },
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: refreshCurrent,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter > 320) return false;
          final appState = context.read<AppState>();
          switch (widget.selectedSegment) {
            case 'pr':
              appState.loadMorePurchaseReceipts();
            case 'pi':
              appState.loadMorePurchaseInvoices();
            case 'po':
            default:
              appState.loadMorePurchaseOrders();
          }
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            ErpPeriodFilterCard(
              title: 'Periode Pembelian',
              subtitle:
                  'PO, receipt, invoice, dan total Rp mengikuti bulan ini',
              icon: Icons.shopping_bag_rounded,
              selectedYear: appState.buyingPeriodYear,
              selectedMonth: appState.buyingPeriodMonth,
              loading: appState.isOrderSummaryLoading,
              onChanged: (year, month) => context
                  .read<AppState>()
                  .setBuyingPeriod(year: year, month: month),
            ),
            const SizedBox(height: 12),
            ErpSegmentBar(
              options: segments,
              selectedId: widget.selectedSegment,
              onSelected: (id) {
                widget.onSegmentChanged?.call(id);
                final appState = context.read<AppState>();
                switch (id) {
                  case 'pr':
                    if (appState.purchaseReceipts.isEmpty) {
                      appState.refreshPurchaseReceipts();
                    }
                  case 'pi':
                    if (appState.purchaseInvoices.isEmpty) {
                      appState.refreshPurchaseInvoices();
                    }
                  case 'po':
                  default:
                    if (appState.purchaseOrders.isEmpty) {
                      appState.refreshPurchaseOrders();
                    }
                }
              },
            ),
            const SizedBox(height: 14),
            switch (widget.selectedSegment) {
              'pr' => const PurchaseReceiptPanel(),
              'pi' => const PurchaseInvoicePanel(),
              _ => const PurchaseOrderPanel(),
            },
          ],
        ),
      ),
    );
  }
}
