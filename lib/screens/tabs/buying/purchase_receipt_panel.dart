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
import '../../../widgets/erp/erp_workflow_helper.dart';
import 'buying_document_detail_sheet.dart';

class PurchaseReceiptPanel extends StatefulWidget {
  const PurchaseReceiptPanel({super.key});

  @override
  State<PurchaseReceiptPanel> createState() => _PurchaseReceiptPanelState();
}

class _PurchaseReceiptPanelState extends State<PurchaseReceiptPanel> {
  final ImagePicker _picker = ImagePicker();
  String _search = '';
  DeliveryNoteStatusKey? _statusFilter;
  Timer? _searchDebounce;

  static final _chips = <ErpStatusChip<DeliveryNoteStatusKey?>>[
    const ErpStatusChip(label: 'All', value: null),
    const ErpStatusChip(label: 'Draft', value: DeliveryNoteStatusKey.draft),
    const ErpStatusChip(label: 'To Bill', value: DeliveryNoteStatusKey.toBill),
    const ErpStatusChip(
      label: 'Completed',
      value: DeliveryNoteStatusKey.completed,
    ),
    const ErpStatusChip(
      label: 'Return Issued',
      value: DeliveryNoteStatusKey.returnIssued,
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
    DeliveryNoteStatusKey.completed => 'Completed',
    DeliveryNoteStatusKey.returnIssued => 'Return Issued',
    DeliveryNoteStatusKey.returnDoc => 'Return',
    DeliveryNoteStatusKey.cancelled => 'Cancelled',
    DeliveryNoteStatusKey.closed => 'Closed',
    _ => null,
  };

  void _searchChanged(String value) {
    setState(() => _search = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      context.read<AppState>().setPurchaseReceiptQuery(
        search: value,
        status: _statusText,
      );
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
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReceiptVarianceCard(receipt: detail),
          const SizedBox(height: 10),
          _ReceiptQcCard(receipt: detail),
          const SizedBox(height: 12),
          erpActionButton(
            label: 'Upload Foto Penerimaan',
            icon: Icons.add_a_photo_outlined,
            onPressed: () => _pickAndUploadEvidence(detail.id),
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
      ),
    );
  }

  String _receiptItemNote(PurchaseReceiptItem item) {
    final parts = <String>[
      if (item.warehouse.isNotEmpty) item.warehouse,
      if (item.purchaseOrder.isNotEmpty) item.purchaseOrder,
      if (item.qualityInspection.isNotEmpty) item.qualityInspection,
    ];
    return parts.join(' | ');
  }

  Future<void> _pickAndUploadEvidence(String receiptId) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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

    try {
      await context.read<AppState>().uploadAttachment(
        doctype: 'Purchase Receipt',
        documentName: receiptId,
        filePath: photo.path,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Foto penerimaan terpasang ke $receiptId.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyUploadError(error)),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  String _friendlyUploadError(Object error) {
    final message = error.toString();
    if (message.contains('File') || message.contains('permission')) {
      return 'Upload foto belum bisa. Cek permission File di ERPNext.';
    }
    return 'Upload foto gagal. Coba lagi setelah koneksi stabil.';
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
            hintText: 'Cari PR atau supplier',
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
          const ErpEmptyState(
            title: 'Belum ada Purchase Receipt',
            message: 'Gunakan tombol Terima Barang untuk mencatat penerimaan.',
          )
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
                    ? 'Memuat receipt...'
                    : 'Muat receipt lainnya',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReceiptVarianceCard extends StatelessWidget {
  final PurchaseReceipt receipt;

  const _ReceiptVarianceCard({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final hasItems = receipt.items.isNotEmpty;
    final hasVariance = receipt.totalVarianceQty.abs() > 0.0001;

    return _ReceiptInfoCard(
      icon: Icons.rule_folder_outlined,
      title: 'Tracking Selisih Quantity',
      subtitle: hasItems
          ? 'Pantau qty diterima, accepted, rejected, dan selisih.'
          : 'Detail item belum tersedia untuk menghitung selisih.',
      child: hasItems
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ReceiptMiniStat(
                        label: 'Received',
                        value: formatErpCurrency(receipt.totalReceivedQty),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ReceiptMiniStat(
                        label: 'Accepted',
                        value: formatErpCurrency(receipt.totalAcceptedQty),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ReceiptMiniStat(
                        label: 'Rejected',
                        value: formatErpCurrency(receipt.totalRejectedQty),
                        warning: receipt.totalRejectedQty > 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...receipt.items.map(_ReceiptVarianceLine.new),
                if (!hasVariance) ...[
                  const SizedBox(height: 8),
                  const _ReceiptNote(
                    icon: Icons.check_circle_outline_rounded,
                    message:
                        'Belum ada selisih qty tercatat pada item penerimaan ini.',
                    success: true,
                  ),
                ],
              ],
            )
          : const _ReceiptNote(
              icon: Icons.info_outline_rounded,
              message:
                  'Buka permission item Purchase Receipt jika detail item belum tampil.',
            ),
    );
  }
}

class _ReceiptQcCard extends StatelessWidget {
  final PurchaseReceipt receipt;

  const _ReceiptQcCard({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final qcItems = receipt.items
        .where((item) => item.qualityInspection.isNotEmpty)
        .toList();

    return _ReceiptInfoCard(
      icon: Icons.fact_check_outlined,
      title: 'QC Penerimaan',
      subtitle: qcItems.isEmpty
          ? 'QC belum terhubung, penerimaan tetap bisa dipantau.'
          : '${qcItems.length} item memiliki Quality Inspection.',
      child: qcItems.isEmpty
          ? const _ReceiptNote(
              icon: Icons.info_outline_rounded,
              message:
                  'Jika Quality Inspection nanti diaktifkan, nomor QC akan tampil otomatis di sini.',
            )
          : Column(
              children: qcItems
                  .map(
                    (item) => _ReceiptReferenceRow(
                      title: item.qualityInspection,
                      subtitle: item.itemName,
                      icon: Icons.verified_outlined,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _ReceiptInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _ReceiptInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ReceiptMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool warning;

  const _ReceiptMiniStat({
    required this.label,
    required this.value,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: warning
            ? AppColors.danger.withValues(alpha: 0.08)
            : AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: warning ? AppColors.danger : AppColors.slate,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: warning ? AppColors.danger : AppColors.navy,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptVarianceLine extends StatelessWidget {
  final PurchaseReceiptItem item;

  const _ReceiptVarianceLine(this.item);

  @override
  Widget build(BuildContext context) {
    final variance = item.varianceQty;
    final hasVariance = variance.abs() > 0.0001;
    final uom = item.uom.isEmpty ? '' : ' ${item.uom}';
    final poText = item.purchaseOrder.isEmpty
        ? 'PO reference belum tercatat'
        : item.purchaseOrder;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: hasVariance
                  ? AppColors.warning.withValues(alpha: 0.14)
                  : AppColors.softGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasVariance ? Icons.priority_high_rounded : Icons.check_rounded,
              color: hasVariance ? AppColors.warning : AppColors.primary,
              size: 17,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  poText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Received ${formatErpCurrency(item.receivedQty)}$uom | '
                  'Checked ${formatErpCurrency(item.checkedQty)}$uom',
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${variance >= 0 ? '+' : ''}${formatErpCurrency(variance)}',
            style: TextStyle(
              color: hasVariance ? AppColors.warning : AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptReferenceRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _ReceiptReferenceRow({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptNote extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool success;

  const _ReceiptNote({
    required this.icon,
    required this.message,
    this.success = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: success
            ? AppColors.softGreen
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: success ? AppColors.primary : AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: success ? AppColors.primary : AppColors.navy,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
