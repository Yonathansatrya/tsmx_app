import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/purchase_order.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/erp_doc_utils.dart';
import '../../../utils/erp_format.dart';
import '../../../widgets/erp/erp_document_card.dart';
import '../../../widgets/erp/erp_detail_sheet.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import '../../../widgets/erp/erp_status_chip_bar.dart';
import '../../../widgets/erp/erp_summary_card.dart';
import '../../../widgets/erp/erp_workflow_helper.dart';

class PurchaseOrderPanel extends StatefulWidget {
  const PurchaseOrderPanel({super.key});

  @override
  State<PurchaseOrderPanel> createState() => _PurchaseOrderPanelState();
}

class _PurchaseOrderPanelState extends State<PurchaseOrderPanel> {
  String _search = '';
  PurchaseOrderStatusKey? _statusFilter;
  bool _delayedOnly = false;

  static final _chips = <ErpStatusChip<PurchaseOrderStatusKey?>>[
    const ErpStatusChip(label: 'All', value: null),
    const ErpStatusChip(label: 'Draft', value: PurchaseOrderStatusKey.draft),
    const ErpStatusChip(label: 'On Hold', value: PurchaseOrderStatusKey.onHold),
    const ErpStatusChip(
      label: 'Receive & Bill',
      value: PurchaseOrderStatusKey.toReceiveAndBill,
    ),
    const ErpStatusChip(label: 'To Receive', value: PurchaseOrderStatusKey.toReceive),
    const ErpStatusChip(label: 'To Bill', value: PurchaseOrderStatusKey.toBill),
    const ErpStatusChip(label: 'To Pay', value: PurchaseOrderStatusKey.toPay),
    const ErpStatusChip(label: 'Completed', value: PurchaseOrderStatusKey.completed),
    const ErpStatusChip(label: 'Delivered', value: PurchaseOrderStatusKey.delivered),
    const ErpStatusChip(label: 'Closed', value: PurchaseOrderStatusKey.closed),
    const ErpStatusChip(label: 'Cancelled', value: PurchaseOrderStatusKey.cancelled),
    const ErpStatusChip(label: 'Delayed', value: PurchaseOrderStatusKey.delayed),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.purchaseOrders.isEmpty) {
        appState.refreshPurchaseOrders();
      }
    });
  }

  List<PurchaseOrder> _filter(List<PurchaseOrder> orders) {
    final q = _search.toLowerCase();
    return orders.where((o) {
      final matchSearch =
          q.isEmpty ||
          o.id.toLowerCase().contains(q) ||
          o.vendor.toLowerCase().contains(q);
      if (_delayedOnly) return matchSearch && o.isDelayed;
      final matchStatus =
          _statusFilter == null || o.statusKey == _statusFilter;
      return matchSearch && matchStatus;
    }).toList();
  }

  Future<void> _openDetail(PurchaseOrder order) async {
    final detail = await context.read<AppState>().loadPurchaseOrderDetail(order.id);
    if (!mounted) return;

    final canReceive =
        isDocSubmitted(detail.docStatus) && detail.perReceived < 100;
    final canBill =
        isDocSubmitted(detail.docStatus) && detail.perBilled < 100;
    final canSubmit = isDocDraft(detail.docStatus);

    showErpDetailSheet(
      context: context,
      title: detail.id,
      subtitle: detail.vendor,
      statusText: detail.isDelayed ? 'Delayed (ETA)' : detail.statusText,
      rows: [
        docStatusRow(detail.docStatus),
        ErpDetailRow(label: 'ERP Status', value: detail.statusText),
        ErpDetailRow(label: 'Expected', value: detail.eta.isEmpty ? '—' : detail.eta),
        if (isDocSubmitted(detail.docStatus)) ...[
          ErpDetailRow(
            label: '% Received',
            value: '${detail.perReceived.toStringAsFixed(1)}%',
          ),
          ErpDetailRow(
            label: '% Billed',
            value: '${detail.perBilled.toStringAsFixed(1)}%',
          ),
        ],
        ErpDetailRow(
          label: 'Total',
          value: 'Rp ${formatErpCurrency(detail.totalValue)}',
        ),
        ErpDetailRow(label: 'Items', value: '${detail.itemsCount}'),
        if (detail.items.isNotEmpty)
          ...detail.items.take(8).map(
            (i) => ErpDetailRow(
              label: i.itemName,
              value: '${i.qty} × ${formatErpCurrency(i.rate)}',
            ),
          ),
      ],
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canSubmit)
            erpActionButton(
              label: 'Submit Purchase Order',
              icon: Icons.check_circle_outline_rounded,
              filled: true,
              onPressed: () => _submitPo(detail.id),
            ),
          if (canReceive)
            erpActionButton(
              label: 'Create Purchase Receipt',
              icon: Icons.inventory_2_outlined,
              onPressed: () => _createPr(detail.id),
            ),
          if (canBill)
            erpActionButton(
              label: 'Create Purchase Invoice',
              icon: Icons.receipt_outlined,
              onPressed: () => _createPi(detail.id),
            ),
          if (!canSubmit && !canReceive && !canBill)
            const Text(
              'No workflow actions available for this document.',
              style: TextStyle(fontSize: 12, color: AppColors.slate),
            ),
        ],
      ),
    );
  }

  Future<void> _submitPo(String id) async {
    if (!await confirmErpAction(
      context,
      title: 'Submit Purchase Order?',
      message: 'Submit $id to ERPNext?',
    )) {
      return;
    }
    final ok = await runErpWorkflowAction(
      context,
      action: () => context.read<AppState>().submitDocument('Purchase Order', id),
      successMessage: 'Purchase Order submitted',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _createPr(String poId) async {
    final ok = await runErpWorkflowAction(
      context,
      action: () => context.read<AppState>().createPurchaseReceiptFromPurchaseOrder(poId),
      successMessage: 'Purchase Receipt created',
    );
    if (ok && mounted) {
      Navigator.pop(context);
      await context.read<AppState>().refreshPurchaseReceipts();
    }
  }

  Future<void> _createPi(String poId) async {
    final ok = await runErpWorkflowAction(
      context,
      action: () => context.read<AppState>().createPurchaseInvoiceFromPurchaseOrder(poId),
      successMessage: 'Purchase Invoice created',
    );
    if (ok && mounted) {
      Navigator.pop(context);
      await context.read<AppState>().refreshPurchaseInvoices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = _filter(appState.purchaseOrders);
    final total = filtered.fold<double>(0, (s, o) => s + o.totalValue);
    final delayedCount =
        appState.purchaseOrders.where((o) => o.isDelayed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ErpSummaryCard(
          title: 'Purchase Orders',
          valueLabel: 'orders',
          totalValue: total,
          documentCount: filtered.length,
          subtitle: delayedCount > 0 ? '$delayedCount delayed by ETA' : null,
          isLoading: appState.isPurchaseOrdersLoading,
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search PO or supplier…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
            ),
          ),
        ),
        if (appState.purchaseOrdersError != null) ...[
          const SizedBox(height: 10),
          ErpErrorBox(message: appState.purchaseOrdersError!),
        ],
        const SizedBox(height: 10),
        ErpStatusChipBar<PurchaseOrderStatusKey?>(
          chips: _chips,
          selected: _delayedOnly ? PurchaseOrderStatusKey.delayed : _statusFilter,
          onSelected: (v) => setState(() {
            if (v == PurchaseOrderStatusKey.delayed) {
              _delayedOnly = true;
              _statusFilter = null;
            } else {
              _delayedOnly = false;
              _statusFilter = v;
            }
          }),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty && !appState.isPurchaseOrdersLoading)
          const ErpEmptyState(title: 'No purchase orders found')
        else
          ...filtered.map(
            (o) => ErpDocumentCard(
              id: o.id,
              party: o.vendor,
              statusText: o.isDelayed ? 'Delayed' : o.statusText,
              date: o.eta,
              value: o.totalValue,
              onTap: () => _openDetail(o),
            ),
          ),
      ],
    );
  }
}
