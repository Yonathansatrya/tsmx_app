import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/erp/erp_segment_bar.dart';
import 'selling/sales_order_panel.dart';
import 'selling/delivery_note_panel.dart';
import 'selling/sales_invoice_panel.dart';
import 'selling/quotation_panel.dart';

class SellingTab extends StatefulWidget {
  const SellingTab({super.key});

  @override
  State<SellingTab> createState() => SellingTabState();
}

class SellingTabState extends State<SellingTab> {
  static const segments = [
    ErpSegmentOption(id: 'so', label: 'Sales Order'),
    ErpSegmentOption(id: 'dn', label: 'Delivery'),
    ErpSegmentOption(id: 'si', label: 'Invoice'),
    ErpSegmentOption(id: 'qt', label: 'Quote'),
  ];

  String _segment = 'so';

  String get currentSegment => _segment;

  Future<void> refreshCurrent() async {
    final appState = context.read<AppState>();
    switch (_segment) {
      case 'dn':
        await appState.refreshDeliveryNotes();
      case 'si':
        await appState.refreshSalesInvoices();
      case 'qt':
        await appState.refreshQuotations();
      case 'so':
      default:
        await appState.refreshSalesOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: refreshCurrent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          ErpSegmentBar(
            options: segments,
            selectedId: _segment,
            onSelected: (id) {
              setState(() => _segment = id);
              final appState = context.read<AppState>();
              switch (id) {
                case 'dn':
                  if (appState.deliveryNotes.isEmpty) {
                    appState.refreshDeliveryNotes();
                  }
                case 'si':
                  if (appState.salesInvoices.isEmpty) {
                    appState.refreshSalesInvoices();
                  }
                case 'qt':
                  if (appState.quotations.isEmpty) {
                    appState.refreshQuotations();
                  }
                case 'so':
                default:
                  if (appState.salesOrders.isEmpty) {
                    appState.refreshSalesOrders();
                  }
              }
            },
          ),
          const SizedBox(height: 14),
          switch (_segment) {
            'dn' => const DeliveryNotePanel(),
            'si' => const SalesInvoicePanel(),
            'qt' => const QuotationPanel(),
            _ => const SalesOrderPanel(),
          },
        ],
      ),
    );
  }
}
