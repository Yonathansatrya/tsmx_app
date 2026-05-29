import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/erp/erp_segment_bar.dart';
import 'buying/purchase_order_panel.dart';
import 'buying/purchase_receipt_panel.dart';
import 'buying/purchase_invoice_panel.dart';
import 'buying/material_request_panel.dart';

class BuyingTab extends StatefulWidget {
  const BuyingTab({super.key});

  @override
  State<BuyingTab> createState() => BuyingTabState();
}

class BuyingTabState extends State<BuyingTab> {
  static const segments = [
    ErpSegmentOption(id: 'po', label: 'Purchase Order'),
    ErpSegmentOption(id: 'pr', label: 'Receipt'),
    ErpSegmentOption(id: 'pi', label: 'Invoice'),
    ErpSegmentOption(id: 'mr', label: 'MR'),
  ];

  String _segment = 'po';

  String get currentSegment => _segment;

  Future<void> refreshCurrent() async {
    final appState = context.read<AppState>();
    switch (_segment) {
      case 'pr':
        await appState.refreshPurchaseReceipts();
      case 'pi':
        await appState.refreshPurchaseInvoices();
      case 'mr':
        await appState.refreshMaterialRequests();
      case 'po':
      default:
        await appState.refreshPurchaseOrders();
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
                case 'pr':
                  if (appState.purchaseReceipts.isEmpty) {
                    appState.refreshPurchaseReceipts();
                  }
                case 'pi':
                  if (appState.purchaseInvoices.isEmpty) {
                    appState.refreshPurchaseInvoices();
                  }
                case 'mr':
                  if (appState.materialRequests.isEmpty) {
                    appState.refreshMaterialRequests();
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
          switch (_segment) {
            'pr' => const PurchaseReceiptPanel(),
            'pi' => const PurchaseInvoicePanel(),
            'mr' => const MaterialRequestPanel(),
            _ => const PurchaseOrderPanel(),
          },
        ],
      ),
    );
  }
}
