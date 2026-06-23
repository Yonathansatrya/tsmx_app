import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/purchase_invoice.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/erp_doc_utils.dart';
import '../../../utils/erp_format.dart';
import '../../../utils/frappe_status.dart';
import '../../../widgets/erp/document_trend_card.dart';
import '../../../widgets/erp/erp_document_card.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import '../../../widgets/erp/erp_status_chip_bar.dart';
import '../../../widgets/erp/erp_workflow_helper.dart';
import 'buying_document_detail_sheet.dart';

class PurchaseInvoicePanel extends StatefulWidget {
  const PurchaseInvoicePanel({super.key});

  @override
  State<PurchaseInvoicePanel> createState() => _PurchaseInvoicePanelState();
}

class _PurchaseInvoicePanelState extends State<PurchaseInvoicePanel> {
  String _search = '';
  InvoiceStatusKey? _statusFilter;
  Timer? _searchDebounce;

  static final _chips = <ErpStatusChip<InvoiceStatusKey?>>[
    const ErpStatusChip(label: 'All', value: null),
    const ErpStatusChip(label: 'Draft', value: InvoiceStatusKey.draft),
    const ErpStatusChip(label: 'Unpaid', value: InvoiceStatusKey.unpaid),
    const ErpStatusChip(
      label: 'Partly Paid',
      value: InvoiceStatusKey.partlyPaid,
    ),
    const ErpStatusChip(label: 'Paid', value: InvoiceStatusKey.paid),
    const ErpStatusChip(label: 'Overdue', value: InvoiceStatusKey.overdue),
    const ErpStatusChip(label: 'Return', value: InvoiceStatusKey.returnDoc),
    const ErpStatusChip(
      label: 'Credit Note',
      value: InvoiceStatusKey.creditNoteIssued,
    ),
    const ErpStatusChip(label: 'Cancelled', value: InvoiceStatusKey.cancelled),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.purchaseInvoices.isEmpty) {
        appState.refreshPurchaseInvoices();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  String? get _statusText => switch (_statusFilter) {
    InvoiceStatusKey.draft => 'Draft',
    InvoiceStatusKey.unpaid => 'Unpaid',
    InvoiceStatusKey.partlyPaid => 'Partly Paid',
    InvoiceStatusKey.paid => 'Paid',
    InvoiceStatusKey.overdue => 'Overdue',
    InvoiceStatusKey.returnDoc => 'Return',
    InvoiceStatusKey.creditNoteIssued => 'Credit Note Issued',
    InvoiceStatusKey.cancelled => 'Cancelled',
    _ => null,
  };

  void _searchChanged(String value) {
    setState(() => _search = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        context.read<AppState>().setPurchaseInvoiceQuery(
          search: value,
          status: _statusText,
        );
      }
    });
  }

  List<PurchaseInvoice> _filter(List<PurchaseInvoice> docs) {
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

  Future<void> _openDetail(PurchaseInvoice doc) async {
    final detail = await context.read<AppState>().loadPurchaseInvoiceDetail(
      doc.id,
    );
    if (!mounted) return;

    final canSubmit = isDocDraft(detail.docStatus);

    showBuyingDocumentDetailSheet(
      context: context,
      title: detail.id,
      subtitle: detail.supplier,
      statusText: detail.statusText,
      icon: Icons.receipt_long_rounded,
      metrics: [
        BuyingDetailMetric(
          label: 'Grand Total',
          value: 'Rp ${formatErpCurrency(detail.value)}',
          icon: Icons.payments_outlined,
        ),
        BuyingDetailMetric(
          label: 'Outstanding',
          value: 'Rp ${formatErpCurrency(detail.outstandingAmount)}',
          icon: Icons.account_balance_wallet_outlined,
        ),
        BuyingDetailMetric(
          label: 'Items',
          value: '${detail.items.length}',
          icon: Icons.inventory_2_outlined,
        ),
      ],
      infos: [
        BuyingDetailInfo(
          label: 'Doc Status',
          value: docStatusLabel(detail.docStatus),
        ),
        BuyingDetailInfo(label: 'Posting Date', value: detail.date),
        BuyingDetailInfo(
          label: 'Due Date',
          value: detail.dueDate.isEmpty ? '-' : detail.dueDate,
        ),
      ],
      items: detail.items
          .map(
            (i) => BuyingDetailItem(
              title: i.itemName,
              subtitle: i.itemCode,
              qty:
                  '${formatErpCurrency(i.qty)}${i.uom.isEmpty ? '' : ' ${i.uom}'}',
              rate: 'Rp ${formatErpCurrency(i.rate)}',
              amount: 'Rp ${formatErpCurrency(i.amount)}',
              note: i.warehouse,
            ),
          )
          .toList(),
      footer: canSubmit
          ? erpActionButton(
              label: 'Submit Purchase Invoice',
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
      title: 'Submit Purchase Invoice?',
      message: 'Submit $id?',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await runErpWorkflowAction(
      context,
      action: () =>
          context.read<AppState>().submitDocument('Purchase Invoice', id),
      successMessage: 'Purchase Invoice submitted',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = _filter(appState.purchaseInvoices);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DocumentTrendCard(
          title: 'Purchase Invoice',
          emptyMessage: 'Belum ada Purchase Invoice aktif pada periode ini.',
          points: appState.purchaseInvoiceTrendPoints,
          selectedYear: appState.buyingPeriodYear,
          selectedMonth: appState.buyingPeriodMonth,
        ),

        const SizedBox(height: 12),

        TextField(
          onChanged: _searchChanged,
          decoration: InputDecoration(
            hintText: 'Search PI or supplier…',
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

        if (appState.purchaseInvoicesError != null) ...[
          const SizedBox(height: 10),
          ErpErrorBox(message: appState.purchaseInvoicesError!),
        ],

        const SizedBox(height: 10),

        ErpStatusChipBar<InvoiceStatusKey?>(
          chips: _chips,
          selected: _statusFilter,
          onSelected: (v) {
            setState(() => _statusFilter = v);
            context.read<AppState>().setPurchaseInvoiceQuery(
              search: _search,
              status: _statusText,
            );
          },
        ),

        const SizedBox(height: 12),

        if (filtered.isEmpty && !appState.isPurchaseInvoicesLoading)
          const ErpEmptyState(title: 'No purchase invoices found')
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
        if (appState.hasMorePurchaseInvoices ||
            appState.isMorePurchaseInvoicesLoading) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: appState.isMorePurchaseInvoicesLoading
                  ? null
                  : () => context.read<AppState>().loadMorePurchaseInvoices(),
              icon: appState.isMorePurchaseInvoicesLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(
                appState.isMorePurchaseInvoicesLoading
                    ? 'Loading invoices...'
                    : 'Load more invoices',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
