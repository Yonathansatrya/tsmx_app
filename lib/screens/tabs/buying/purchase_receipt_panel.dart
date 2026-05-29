import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/purchase_receipt.dart';
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

class PurchaseReceiptPanel extends StatefulWidget {
  const PurchaseReceiptPanel({super.key});

  @override
  State<PurchaseReceiptPanel> createState() => _PurchaseReceiptPanelState();
}

class _PurchaseReceiptPanelState extends State<PurchaseReceiptPanel> {
  String _search = '';
  DeliveryNoteStatusKey? _statusFilter;

  static final _chips = <ErpStatusChip<DeliveryNoteStatusKey?>>[
    const ErpStatusChip(label: 'All', value: null),
    const ErpStatusChip(label: 'Draft', value: DeliveryNoteStatusKey.draft),
    const ErpStatusChip(label: 'To Bill', value: DeliveryNoteStatusKey.toBill),
    const ErpStatusChip(
      label: 'Partly Billed',
      value: DeliveryNoteStatusKey.partiallyBilled,
    ),
    const ErpStatusChip(label: 'Completed', value: DeliveryNoteStatusKey.completed),
    const ErpStatusChip(label: 'Cancelled', value: DeliveryNoteStatusKey.cancelled),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.purchaseReceipts.isEmpty) {
        appState.refreshPurchaseReceipts();
      }
    });
  }

  List<PurchaseReceipt> _filter(List<PurchaseReceipt> docs) {
    final q = _search.toLowerCase();
    return docs.where((d) {
      final matchSearch =
          q.isEmpty ||
          d.id.toLowerCase().contains(q) ||
          d.supplier.toLowerCase().contains(q);
      final matchStatus = _statusFilter == null || d.statusKey == _statusFilter;
      return matchSearch && matchStatus;
    }).toList();
  }

  Future<void> _openDetail(PurchaseReceipt doc) async {
    final detail = await context.read<AppState>().loadPurchaseReceiptDetail(doc.id);
    if (!mounted) return;

    final canSubmit = isDocDraft(detail.docStatus);

    showErpDetailSheet(
      context: context,
      title: detail.id,
      subtitle: detail.supplier,
      statusText: detail.statusText,
      rows: [
        docStatusRow(detail.docStatus),
        ErpDetailRow(label: 'Posting Date', value: detail.date),
        ErpDetailRow(
          label: 'Total',
          value: 'Rp ${formatErpCurrency(detail.value)}',
        ),
        ErpDetailRow(label: 'Qty', value: '${detail.itemsCount}'),
      ],
      footer: canSubmit
          ? erpActionButton(
              label: 'Submit Purchase Receipt',
              icon: Icons.check_circle_outline_rounded,
              filled: true,
              onPressed: () => _submit(detail.id),
            )
          : null,
    );
  }

  Future<void> _submit(String id) async {
    if (!await confirmErpAction(
      context,
      title: 'Submit Purchase Receipt?',
      message: 'Submit $id to ERPNext?',
    )) {
      return;
    }
    final ok = await runErpWorkflowAction(
      context,
      action: () => context.read<AppState>().submitDocument('Purchase Receipt', id),
      successMessage: 'Purchase Receipt submitted',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = _filter(appState.purchaseReceipts);
    final total = filtered.fold<double>(0, (s, d) => s + d.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ErpSummaryCard(
          title: 'Purchase Receipts',
          valueLabel: 'documents',
          totalValue: total,
          documentCount: filtered.length,
          isLoading: appState.isPurchaseReceiptsLoading,
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search PR or supplier…',
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
        if (appState.purchaseReceiptsError != null) ...[
          const SizedBox(height: 10),
          ErpErrorBox(message: appState.purchaseReceiptsError!),
        ],
        const SizedBox(height: 10),
        ErpStatusChipBar<DeliveryNoteStatusKey?>(
          chips: _chips,
          selected: _statusFilter,
          onSelected: (v) => setState(() => _statusFilter = v),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty && !appState.isPurchaseReceiptsLoading)
          const ErpEmptyState(title: 'No purchase receipts found')
        else
          ...filtered.map(
            (d) => ErpDocumentCard(
              id: d.id,
              party: d.supplier,
              statusText: d.statusText,
              date: d.date,
              value: d.value,
              onTap: () => _openDetail(d),
            ),
          ),
      ],
    );
  }
}
