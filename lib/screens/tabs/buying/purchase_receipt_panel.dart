import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../models/purchase_receipt.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/erp_doc_utils.dart';
import '../../../utils/erp_format.dart';
import '../../../widgets/erp/document_trend_card.dart';
import '../../../widgets/erp/erp_document_card.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import '../../../widgets/erp/erp_status_chip_bar.dart';
import '../../../widgets/erp/erp_summary_card.dart';
import '../../../widgets/erp/erp_workflow_helper.dart';
import '../../warehouse/warehouse_incoming_qc_screen.dart';
import 'buying_document_detail_sheet.dart';

class PurchaseReceiptPanel extends StatefulWidget {
  const PurchaseReceiptPanel({super.key});

  @override
  State<PurchaseReceiptPanel> createState() => _PurchaseReceiptPanelState();
}

class _PurchaseReceiptPanelState extends State<PurchaseReceiptPanel> {
  final _picker = ImagePicker();
  String _search = '';
  DeliveryNoteStatusKey? _statusFilter;
  Timer? _searchDebounce;

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
      label: 'Return Issued',
      value: DeliveryNoteStatusKey.returnIssued,
    ),
    const ErpStatusChip(label: 'Closed', value: DeliveryNoteStatusKey.closed),
    const ErpStatusChip(
      label: 'Cancelled',
      value: DeliveryNoteStatusKey.cancelled,
    ),
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  String? get _statusText => switch (_statusFilter) {
    DeliveryNoteStatusKey.draft => 'Draft',
    DeliveryNoteStatusKey.toBill => 'To Bill',
    DeliveryNoteStatusKey.partiallyBilled => 'Partially Billed',
    DeliveryNoteStatusKey.completed => 'Completed',
    DeliveryNoteStatusKey.returnDoc => 'Return',
    DeliveryNoteStatusKey.returnIssued => 'Return Issued',
    DeliveryNoteStatusKey.closed => 'Closed',
    DeliveryNoteStatusKey.cancelled => 'Cancelled',
    _ => null,
  };

  void _searchChanged(String value) {
    setState(() => _search = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        context.read<AppState>().setPurchaseReceiptQuery(
          search: value,
          status: _statusText,
        );
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
    final detail = await context.read<AppState>().loadPurchaseReceiptDetail(
      doc.id,
    );
    if (!mounted) return;

    final canSubmit = isDocDraft(detail.docStatus);

    showBuyingDocumentDetailSheet(
      context: context,
      title: detail.id,
      subtitle: detail.supplier,
      statusText: detail.statusText,
      icon: Icons.move_to_inbox_rounded,
      metrics: [
        BuyingDetailMetric(
          label: 'Total',
          value: 'Rp ${formatErpCurrency(detail.value)}',
          icon: Icons.payments_outlined,
        ),
        BuyingDetailMetric(
          label: 'Qty',
          value: '${detail.itemsCount}',
          icon: Icons.inventory_2_outlined,
        ),
      ],
      infos: [
        BuyingDetailInfo(
          label: 'Doc Status',
          value: docStatusLabel(detail.docStatus),
        ),
        BuyingDetailInfo(label: 'Posting Date', value: detail.date),
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
              note: _receiptItemNote(i),
            ),
          )
          .toList(),
      footer: _detailActions(detail, canSubmit: canSubmit),
    );
  }

  String _receiptItemNote(PurchaseReceiptItem item) {
    final parts = <String>[];
    if (item.warehouse.isNotEmpty) parts.add(item.warehouse);
    if (item.receivedQty > 0 && item.receivedQty != item.qty) {
      parts.add('Received ${formatErpCurrency(item.receivedQty)}');
    }
    if (item.rejectedQty > 0) {
      parts.add('Rejected ${formatErpCurrency(item.rejectedQty)}');
    }
    return parts.join(' | ');
  }

  Widget _detailActions(PurchaseReceipt detail, {required bool canSubmit}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        erpActionButton(
          label: 'Upload Foto Penerimaan',
          icon: Icons.add_a_photo_outlined,
          onPressed: () => _chooseReceiptPhoto(detail),
        ),
        const SizedBox(height: 10),
        erpActionButton(
          label: 'Lihat QC Penerimaan',
          icon: Icons.fact_check_outlined,
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WarehouseIncomingQcScreen(),
              ),
            );
          },
        ),
        if (canSubmit) ...[
          const SizedBox(height: 10),
          erpActionButton(
            label: 'Submit Purchase Receipt',
            icon: Icons.check_circle_outline_rounded,
            filled: true,
            onPressed: () => _submit(detail.id),
          ),
        ],
      ],
    );
  }

  Future<void> _chooseReceiptPhoto(PurchaseReceipt receipt) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tambah foto penerimaan ${receipt.id}',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Ambil foto dengan kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Pilih foto dari galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    final photo = await _picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (photo == null || !mounted) return;

    final ok = await runErpWorkflowAction(
      context,
      action: () => context.read<AppState>().uploadAttachment(
        doctype: 'Purchase Receipt',
        documentName: receipt.id,
        filePath: photo.path,
      ),
      successMessage: 'Foto penerimaan tersimpan',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _submit(String id) async {
    if (!await confirmErpAction(
      context,
      title: 'Submit Purchase Receipt?',
      message: 'Submit $id?',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await runErpWorkflowAction(
      context,
      action: () =>
          context.read<AppState>().submitDocument('Purchase Receipt', id),
      successMessage: 'Purchase Receipt submitted',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = _filter(appState.purchaseReceipts);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ErpSummaryCard(
          title: 'Purchase Receipts',
          valueLabel: 'documents',
          totalValue: appState.purchaseReceiptSummary.totalValue,
          documentCount: appState.purchaseReceiptSummary.documentCount,
          subtitle:
              '${appState.summarySyncSubtitle} | ${filtered.length} loaded',
          isLoading:
              appState.isOrderSummaryLoading &&
              appState.purchaseReceiptSummary.documentCount == 0,
        ),
        const SizedBox(height: 12),
        DocumentTrendCard(
          title: 'Purchase Receipt',
          emptyMessage: 'Belum ada Purchase Receipt aktif pada periode ini.',
          points: appState.purchaseReceiptTrendPoints,
          selectedYear: appState.buyingPeriodYear,
          selectedMonth: appState.buyingPeriodMonth,
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: _searchChanged,
          decoration: InputDecoration(
            hintText: 'Search PR or supplier…',
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
        if (appState.purchaseReceiptsError != null) ...[
          const SizedBox(height: 10),
          ErpErrorBox(message: appState.purchaseReceiptsError!),
        ],
        const SizedBox(height: 10),
        ErpStatusChipBar<DeliveryNoteStatusKey?>(
          chips: _chips,
          selected: _statusFilter,
          onSelected: (v) {
            setState(() => _statusFilter = v);
            context.read<AppState>().setPurchaseReceiptQuery(
              search: _search,
              status: _statusText,
            );
          },
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
        if (appState.hasMorePurchaseReceipts ||
            appState.isMorePurchaseReceiptsLoading) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: appState.isMorePurchaseReceiptsLoading
                  ? null
                  : () => context.read<AppState>().loadMorePurchaseReceipts(),
              icon: appState.isMorePurchaseReceiptsLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(
                appState.isMorePurchaseReceiptsLoading
                    ? 'Loading receipts...'
                    : 'Load more receipts',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
