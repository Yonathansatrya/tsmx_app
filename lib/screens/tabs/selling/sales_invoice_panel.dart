import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/sales_invoice.dart';
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

class SalesInvoicePanel extends StatefulWidget {
  const SalesInvoicePanel({super.key});

  @override
  State<SalesInvoicePanel> createState() => _SalesInvoicePanelState();
}

class _SalesInvoicePanelState extends State<SalesInvoicePanel> {
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
    const ErpStatusChip(label: 'Cancelled', value: InvoiceStatusKey.cancelled),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.salesInvoices.isEmpty) {
        appState.refreshSalesInvoices();
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
    InvoiceStatusKey.cancelled => 'Cancelled',
    _ => null,
  };

  void _searchChanged(String value) {
    setState(() => _search = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        context.read<AppState>().setSalesInvoiceQuery(
          search: value,
          status: _statusText,
        );
      }
    });
  }

  List<SalesInvoice> _filter(List<SalesInvoice> docs) {
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

  Future<void> _openDetail(SalesInvoice doc) async {
    final detail = await context.read<AppState>().loadSalesInvoiceDetail(
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
          label: 'Due Date',
          value: detail.dueDate.isEmpty ? '—' : detail.dueDate,
        ),
        ErpDetailRow(
          label: 'Grand Total',
          value: 'Rp ${formatErpCurrency(detail.value)}',
        ),
        ErpDetailRow(
          label: 'Outstanding',
          value: 'Rp ${formatErpCurrency(detail.outstandingAmount)}',
        ),
      ],
      footer: canSubmit
          ? erpActionButton(
              label: 'Submit Sales Invoice',
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
      title: 'Submit Sales Invoice?',
      message: 'Submit $id to ERPNext?',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await runErpWorkflowAction(
      context,
      action: () =>
          context.read<AppState>().submitDocument('Sales Invoice', id),
      successMessage: 'Sales Invoice submitted',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = _filter(appState.salesInvoices);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ErpSummaryCard(
          title: 'Sales Invoices',
          valueLabel: 'invoices',
          totalValue: appState.salesInvoiceSummary.totalValue,
          documentCount: appState.salesInvoiceSummary.documentCount,
          subtitle:
              '${appState.summarySyncSubtitle} | '
              '${filtered.length} loaded for current filters',
          isLoading:
              appState.isOrderSummaryLoading &&
              appState.salesInvoiceSummary.documentCount == 0,
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: _searchChanged,
          decoration: InputDecoration(
            hintText: 'Search SI or customer…',
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
        if (appState.salesInvoicesError != null) ...[
          const SizedBox(height: 10),
          ErpErrorBox(message: appState.salesInvoicesError!),
        ],
        const SizedBox(height: 10),
        ErpStatusChipBar<InvoiceStatusKey?>(
          chips: _chips,
          selected: _statusFilter,
          onSelected: (v) {
            setState(() => _statusFilter = v);
            context.read<AppState>().setSalesInvoiceQuery(
              search: _search,
              status: _statusText,
            );
          },
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty && !appState.isSalesInvoicesLoading)
          const ErpEmptyState(title: 'No sales invoices found')
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
        if (appState.hasMoreSalesInvoices ||
            appState.isMoreSalesInvoicesLoading) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: appState.isMoreSalesInvoicesLoading
                  ? null
                  : () => context.read<AppState>().loadMoreSalesInvoices(),
              icon: appState.isMoreSalesInvoicesLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(
                appState.isMoreSalesInvoicesLoading
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
