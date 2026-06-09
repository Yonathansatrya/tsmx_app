import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/erp/erp_segment_bar.dart';
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

class SellingTabState extends State<SellingTab> {
  static const segments = [
    ErpSegmentOption(id: 'so', label: 'Sales Order'),
    ErpSegmentOption(id: 'dn', label: 'Delivery Notes'),
    ErpSegmentOption(id: 'si', label: 'Invoices'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshAllSummaries(silent: true);
    });
  }

  Future<void> refreshCurrent() async {
    final appState = context.read<AppState>();
    await Future.wait([
      appState.refreshAllSummaries(),
      switch (widget.selectedSegment) {
        'dn' => appState.refreshDeliveryNotes(),
        'si' => appState.refreshSalesInvoices(),
        _ => appState.refreshSalesOrders(),
      },
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: refreshCurrent,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter > 320) return false;
          final appState = context.read<AppState>();
          switch (widget.selectedSegment) {
            case 'dn':
              appState.loadMoreDeliveryNotes();
            case 'si':
              appState.loadMoreSalesInvoices();
            case 'so':
            default:
              appState.loadMoreSalesOrders();
          }
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            ErpSegmentBar(
              options: segments,
              selectedId: widget.selectedSegment,
              onSelected: (id) {
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
                }
              },
            ),
            const SizedBox(height: 14),
            switch (widget.selectedSegment) {
              'dn' => const DeliveryNotePanel(),
              'si' => const SalesInvoicePanel(),
              _ => const SalesOrderPanel(),
            },
          ],
        ),
      ),
    );
  }
}
