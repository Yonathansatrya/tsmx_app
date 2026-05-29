import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/sales_order.dart';
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

class SalesOrderPanel extends StatefulWidget {
  const SalesOrderPanel({super.key});

  @override
  State<SalesOrderPanel> createState() => _SalesOrderPanelState();
}

class _SalesOrderPanelState extends State<SalesOrderPanel> {
  String _search = '';
  SalesOrderStatusKey? _statusFilter;

  static final _chips = <ErpStatusChip<SalesOrderStatusKey?>>[
    const ErpStatusChip(label: 'All', value: null),
    const ErpStatusChip(label: 'Draft', value: SalesOrderStatusKey.draft),
    const ErpStatusChip(label: 'On Hold', value: SalesOrderStatusKey.onHold),
    const ErpStatusChip(
      label: 'Deliver & Bill',
      value: SalesOrderStatusKey.toDeliverAndBill,
    ),
    const ErpStatusChip(label: 'To Bill', value: SalesOrderStatusKey.toBill),
    const ErpStatusChip(label: 'To Deliver', value: SalesOrderStatusKey.toDeliver),
    const ErpStatusChip(label: 'To Pay', value: SalesOrderStatusKey.toPay),
    const ErpStatusChip(label: 'Completed', value: SalesOrderStatusKey.completed),
    const ErpStatusChip(label: 'Closed', value: SalesOrderStatusKey.closed),
    const ErpStatusChip(label: 'Cancelled', value: SalesOrderStatusKey.cancelled),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.salesOrders.isEmpty) {
        appState.refreshSalesOrders();
      }
    });
  }

  List<SalesOrder> _filter(List<SalesOrder> orders) {
    final q = _search.toLowerCase();
    return orders.where((o) {
      final matchSearch =
          q.isEmpty ||
          o.id.toLowerCase().contains(q) ||
          o.customer.toLowerCase().contains(q);
      final matchStatus =
          _statusFilter == null || o.statusKey == _statusFilter;
      return matchSearch && matchStatus;
    }).toList();
  }

  Future<void> _openDetail(SalesOrder order) async {
    final appState = context.read<AppState>();
    final detail = await appState.loadSalesOrderDetail(order.id);
    if (!mounted) return;

    final relatedDn = await appState.fetchDeliveryNotesForSalesOrder(order.id);
    final relatedSi = await appState.fetchSalesInvoicesForSalesOrder(order.id);
    if (!mounted) return;

    final canDeliver =
        isDocSubmitted(detail.docStatus) && detail.perDelivered < 100;
    final canBill =
        isDocSubmitted(detail.docStatus) && detail.perBilled < 100;
    final canSubmit = isDocDraft(detail.docStatus);

    showErpDetailSheet(
      context: context,
      title: detail.id,
      subtitle: detail.customer,
      statusText: detail.statusText,
      rows: [
        docStatusRow(detail.docStatus),
        ErpDetailRow(label: 'Date', value: detail.date),
        if (isDocSubmitted(detail.docStatus)) ...[
          ErpDetailRow(
            label: '% Delivered',
            value: '${detail.perDelivered.toStringAsFixed(1)}%',
          ),
          ErpDetailRow(
            label: '% Billed',
            value: '${detail.perBilled.toStringAsFixed(1)}%',
          ),
        ],
        ErpDetailRow(
          label: 'Total',
          value: 'Rp ${formatErpCurrency(detail.value)}',
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
          if (relatedDn.isNotEmpty)
            erpWorkflowSection(
              title: 'Delivery Notes',
              children: erpRelatedDocChips(
                docIds: relatedDn.map((d) => d.id).toList(),
                onTap: (_) {},
              ),
            ),
          if (relatedSi.isNotEmpty) ...[
            const SizedBox(height: 8),
            erpWorkflowSection(
              title: 'Sales Invoices',
              children: erpRelatedDocChips(
                docIds: relatedSi.map((d) => d.id).toList(),
                onTap: (_) {},
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (canSubmit)
            erpActionButton(
              label: 'Submit Sales Order',
              icon: Icons.check_circle_outline_rounded,
              filled: true,
              onPressed: () => _submitSo(detail.id),
            ),
          if (canDeliver)
            erpActionButton(
              label: 'Create Delivery Note',
              icon: Icons.local_shipping_outlined,
              onPressed: () => _createDn(detail.id),
            ),
          if (canBill)
            erpActionButton(
              label: 'Create Sales Invoice',
              icon: Icons.receipt_long_outlined,
              onPressed: () => _createSi(detail.id),
            ),
          if (!canSubmit && !canDeliver && !canBill)
            const Text(
              'No workflow actions available for this document.',
              style: TextStyle(fontSize: 12, color: AppColors.slate),
            ),
        ],
      ),
    );
  }

  Future<void> _submitSo(String id) async {
    if (!await confirmErpAction(
      context,
      title: 'Submit Sales Order?',
      message: 'Submit $id to ERPNext?',
    )) {
      return;
    }
    final ok = await runErpWorkflowAction(
      context,
      action: () => context.read<AppState>().submitDocument('Sales Order', id),
      successMessage: 'Sales Order submitted',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _createDn(String soId) async {
    final ok = await runErpWorkflowAction(
      context,
      action: () => context.read<AppState>().createDeliveryNoteFromSalesOrder(soId),
      successMessage: 'Delivery Note created',
    );
    if (ok && mounted) {
      Navigator.pop(context);
      await context.read<AppState>().refreshDeliveryNotes();
    }
  }

  Future<void> _createSi(String soId) async {
    final ok = await runErpWorkflowAction(
      context,
      action: () => context.read<AppState>().createSalesInvoiceFromSalesOrder(soId),
      successMessage: 'Sales Invoice created',
    );
    if (ok && mounted) {
      Navigator.pop(context);
      await context.read<AppState>().refreshSalesInvoices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = _filter(appState.salesOrders);
    final total = filtered.fold<double>(0, (s, o) => s + o.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ErpSummaryCard(
          title: 'Sales Orders',
          valueLabel: 'orders',
          totalValue: total,
          documentCount: filtered.length,
          isLoading: appState.isSalesOrdersLoading,
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search SO or customer…',
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
        if (appState.salesOrdersError != null) ...[
          const SizedBox(height: 10),
          ErpErrorBox(message: appState.salesOrdersError!),
        ],
        const SizedBox(height: 10),
        ErpStatusChipBar<SalesOrderStatusKey?>(
          chips: _chips,
          selected: _statusFilter,
          onSelected: (v) => setState(() => _statusFilter = v),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty && !appState.isSalesOrdersLoading)
          const ErpEmptyState(title: 'No sales orders found')
        else
          ...filtered.map(
            (o) => ErpDocumentCard(
              id: o.id,
              party: o.customer,
              statusText: o.statusText,
              date: o.date,
              value: o.value,
              onTap: () => _openDetail(o),
            ),
          ),
      ],
    );
  }
}
