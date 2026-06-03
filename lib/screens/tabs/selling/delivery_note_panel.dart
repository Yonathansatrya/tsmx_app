import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/delivery_note.dart';
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

class DeliveryNotePanel extends StatefulWidget {
  const DeliveryNotePanel({super.key});

  @override
  State<DeliveryNotePanel> createState() => _DeliveryNotePanelState();
}

class _DeliveryNotePanelState extends State<DeliveryNotePanel> {
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
    const ErpStatusChip(
      label: 'Completed',
      value: DeliveryNoteStatusKey.completed,
    ),
    const ErpStatusChip(
      label: 'Return',
      value: DeliveryNoteStatusKey.returnDoc,
    ),
    const ErpStatusChip(
      label: 'Cancelled',
      value: DeliveryNoteStatusKey.cancelled,
    ),
    const ErpStatusChip(label: 'Closed', value: DeliveryNoteStatusKey.closed),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.deliveryNotes.isEmpty) {
        appState.refreshDeliveryNotes();
      }
    });
  }

  List<DeliveryNote> _filter(List<DeliveryNote> docs) {
    final q = _search.toLowerCase();
    return docs.where((d) {
      final matchSearch =
          q.isEmpty ||
          d.id.toLowerCase().contains(q) ||
          d.customer.toLowerCase().contains(q);
      final matchStatus = _statusFilter == null || d.statusKey == _statusFilter;
      return matchSearch && matchStatus;
    }).toList();
  }

  Future<void> _openDetail(DeliveryNote doc) async {
    final detail = await context.read<AppState>().loadDeliveryNoteDetail(
      doc.id,
    );
    if (!mounted) return;

    final canSubmit = isDocDraft(detail.docStatus);

    showErpDetailSheet(
      context: context,
      title: detail.id,
      subtitle: detail.customer,
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
              label: 'Submit Delivery Note',
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
      title: 'Submit Delivery Note?',
      message: 'Submit $id to ERPNext?',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await runErpWorkflowAction(
      context,
      action: () =>
          context.read<AppState>().submitDocument('Delivery Note', id),
      successMessage: 'Delivery Note submitted',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = _filter(appState.deliveryNotes);
    final total = filtered.fold<double>(0, (s, d) => s + d.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ErpSummaryCard(
          title: 'Delivery Notes',
          valueLabel: 'documents',
          totalValue: total,
          documentCount: filtered.length,
          isLoading: appState.isDeliveryNotesLoading,
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search DN or customer…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ),
        ),
        if (appState.deliveryNotesError != null) ...[
          const SizedBox(height: 10),
          ErpErrorBox(message: appState.deliveryNotesError!),
        ],
        const SizedBox(height: 10),
        ErpStatusChipBar<DeliveryNoteStatusKey?>(
          chips: _chips,
          selected: _statusFilter,
          onSelected: (v) => setState(() => _statusFilter = v),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty && !appState.isDeliveryNotesLoading)
          const ErpEmptyState(title: 'No delivery notes found')
        else
          ...filtered.map(
            (d) => ErpDocumentCard(
              id: d.id,
              party: d.customer,
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
