import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/purchase_order.dart';
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
import '../../purchase/purchase_order/create_purchase_order_screen.dart';
import 'buying_document_detail_sheet.dart';

enum _PurchaseSortOption { newestEta, oldestEta, valueHigh, valueLow }

enum _PoDocStatusFilter { all, draft, submitted, cancelled }

class PurchaseOrderPanel extends StatefulWidget {
  const PurchaseOrderPanel({super.key});

  @override
  State<PurchaseOrderPanel> createState() => _PurchaseOrderPanelState();
}

class _PurchaseOrderPanelState extends State<PurchaseOrderPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  PurchaseOrderStatusKey? _statusFilter;
  _PurchaseSortOption _sortOption = _PurchaseSortOption.newestEta;
  String _advancedSupplier = '';
  String _advancedItem = '';
  String _advancedWarehouse = '';
  double? _advancedMinValue;
  double? _advancedMaxValue;
  DateTime? _advancedFrom;
  DateTime? _advancedTo;
  _PoDocStatusFilter _advancedDocStatus = _PoDocStatusFilter.all;
  Timer? _searchDebounce;

  static final _chips = <ErpStatusChip<PurchaseOrderStatusKey?>>[
    const ErpStatusChip(label: 'All', value: null),
    const ErpStatusChip(label: 'Draft', value: PurchaseOrderStatusKey.draft),
    const ErpStatusChip(label: 'On Hold', value: PurchaseOrderStatusKey.onHold),
    const ErpStatusChip(
      label: 'Receive & Bill',
      value: PurchaseOrderStatusKey.toReceiveAndBill,
    ),
    const ErpStatusChip(
      label: 'To Receive',
      value: PurchaseOrderStatusKey.toReceive,
    ),
    const ErpStatusChip(label: 'To Bill', value: PurchaseOrderStatusKey.toBill),
    const ErpStatusChip(
      label: 'Overdue',
      value: PurchaseOrderStatusKey.overdue,
    ),
    const ErpStatusChip(
      label: 'Completed',
      value: PurchaseOrderStatusKey.completed,
    ),
    const ErpStatusChip(
      label: 'Delivered',
      value: PurchaseOrderStatusKey.delivered,
    ),
    const ErpStatusChip(label: 'Closed', value: PurchaseOrderStatusKey.closed),
    const ErpStatusChip(
      label: 'Cancelled',
      value: PurchaseOrderStatusKey.cancelled,
    ),
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String? get _statusText {
    return switch (_statusFilter) {
      PurchaseOrderStatusKey.draft => 'Draft',
      PurchaseOrderStatusKey.onHold => 'On Hold',
      PurchaseOrderStatusKey.toReceiveAndBill => 'To Receive and Bill',
      PurchaseOrderStatusKey.toReceive => 'To Receive',
      PurchaseOrderStatusKey.toBill => 'To Bill',
      PurchaseOrderStatusKey.overdue => 'Overdue',
      PurchaseOrderStatusKey.completed => 'Completed',
      PurchaseOrderStatusKey.delivered => 'Delivered',
      PurchaseOrderStatusKey.closed => 'Closed',
      PurchaseOrderStatusKey.cancelled => 'Cancelled',
      _ => null,
    };
  }

  void _searchChanged(String value) {
    setState(() => _search = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        context.read<AppState>().setPurchaseOrderQuery(
          search: value,
          status: _statusText,
        );
      }
    });
  }

  List<PurchaseOrder> _filter(List<PurchaseOrder> orders) {
    final q = _search.toLowerCase();
    final filtered = orders.where((o) {
      final matchSearch =
          q.isEmpty ||
          o.id.toLowerCase().contains(q) ||
          o.vendor.toLowerCase().contains(q);
      final matchStatus = _statusFilter == null || o.statusKey == _statusFilter;
      return matchSearch && matchStatus && _matchesAdvancedFilters(o);
    }).toList();

    filtered.sort((a, b) {
      return switch (_sortOption) {
        _PurchaseSortOption.newestEta => _compareDateDesc(a.eta, b.eta),
        _PurchaseSortOption.oldestEta => _compareDateAsc(a.eta, b.eta),
        _PurchaseSortOption.valueHigh => b.totalValue.compareTo(a.totalValue),
        _PurchaseSortOption.valueLow => a.totalValue.compareTo(b.totalValue),
      };
    });

    return filtered;
  }

  int _compareDateDesc(String a, String b) {
    final left = _parseDate(a);
    final right = _parseDate(b);
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
  }

  int _compareDateAsc(String a, String b) {
    final left = _parseDate(a);
    final right = _parseDate(b);
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return left.compareTo(right);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime? _parseDate(String rawDate) {
    final trimmed = rawDate.trim();
    if (trimmed.isEmpty) return null;

    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;

    final parts = trimmed.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  String _sortLabel(_PurchaseSortOption option) {
    return switch (option) {
      _PurchaseSortOption.newestEta => 'Newest ETA',
      _PurchaseSortOption.oldestEta => 'Oldest ETA',
      _PurchaseSortOption.valueHigh => 'Value high',
      _PurchaseSortOption.valueLow => 'Value low',
    };
  }

  Future<void> _openAdvancedFilters() async {
    final result = await showModalBottomSheet<_PurchaseOrderAdvancedFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _PurchaseOrderAdvancedFilterSheet(
        initial: _PurchaseOrderAdvancedFilters(
          supplier: _advancedSupplier,
          item: _advancedItem,
          warehouse: _advancedWarehouse,
          minValue: _advancedMinValue,
          maxValue: _advancedMaxValue,
          from: _advancedFrom,
          to: _advancedTo,
          docStatus: _advancedDocStatus,
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      _advancedSupplier = result.supplier;
      _advancedItem = result.item;
      _advancedWarehouse = result.warehouse;
      _advancedMinValue = result.minValue;
      _advancedMaxValue = result.maxValue;
      _advancedFrom = result.from;
      _advancedTo = result.to;
      _advancedDocStatus = result.docStatus;
    });
  }

  Future<void> _openDetail(PurchaseOrder order) async {
    final appState = context.read<AppState>();
    final detail = await appState.loadPurchaseOrderDetail(order.id);
    var priceRows = <Map<String, dynamic>>[];
    var workflowActions = <String>[];
    try {
      priceRows = await appState.fetchSupplierPriceComparison(
        detail.items.map((item) => item.itemCode).toSet(),
      );
    } catch (_) {}
    try {
      workflowActions = await appState.fetchDocumentWorkflowActions(
        doctype: 'Purchase Order',
        name: detail.id,
      );
    } catch (_) {}
    if (!mounted) return;

    final canReceive =
        isDocSubmitted(detail.docStatus) && detail.perReceived < 100;
    final canBill = isDocSubmitted(detail.docStatus) && detail.perBilled < 100;
    final canSubmit = isDocDraft(detail.docStatus);
    final canEdit = isDocDraft(detail.docStatus);
    final canDelete = isDocDraft(detail.docStatus);
    final canCancel =
        isDocSubmitted(detail.docStatus) &&
        detail.statusKey != PurchaseOrderStatusKey.completed &&
        detail.statusKey != PurchaseOrderStatusKey.closed &&
        detail.statusKey != PurchaseOrderStatusKey.cancelled;

    showBuyingDocumentDetailSheet(
      context: context,
      title: detail.id,
      subtitle: detail.vendor,
      statusText: detail.statusText,
      icon: Icons.shopping_bag_rounded,
      metrics: [
        BuyingDetailMetric(
          label: 'Total',
          value: 'Rp ${formatErpCurrency(detail.totalValue)}',
          icon: Icons.payments_outlined,
        ),
        BuyingDetailMetric(
          label: 'Items',
          value: '${detail.itemsCount}',
          icon: Icons.inventory_2_outlined,
        ),
        BuyingDetailMetric(
          label: 'Received',
          value: '${detail.perReceived.toStringAsFixed(1)}%',
          icon: Icons.move_to_inbox_outlined,
        ),
        BuyingDetailMetric(
          label: 'Billed',
          value: '${detail.perBilled.toStringAsFixed(1)}%',
          icon: Icons.receipt_long_outlined,
        ),
      ],
      infos: [
        BuyingDetailInfo(
          label: 'Doc Status',
          value: docStatusLabel(detail.docStatus),
        ),
        BuyingDetailInfo(label: 'ERP Status', value: detail.statusText),
        BuyingDetailInfo(
          label: 'Expected',
          value: detail.eta.isEmpty ? '-' : detail.eta,
        ),
        if (detail.isOverdue)
          const BuyingDetailInfo(label: 'ETA Risk', value: 'Overdue'),
      ],
      items: detail.items
          .map(
            (i) => BuyingDetailItem(
              title: i.itemName,
              subtitle: i.itemCode,
              qty: '${i.qty}',
              rate: 'Rp ${formatErpCurrency(i.rate)}',
              amount: 'Rp ${formatErpCurrency(i.qty * i.rate)}',
              note: i.warehouse,
            ),
          )
          .toList(),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SupplierPriceComparisonCard(order: detail, priceRows: priceRows),
          const SizedBox(height: 10),
          ..._workflowButtons(
            doctype: 'Purchase Order',
            name: detail.id,
            actions: workflowActions,
          ),
          if (canEdit)
            erpActionButton(
              label: 'Edit Purchase Order',
              icon: Icons.edit_outlined,
              onPressed: () => _editPo(detail.id, closeSheet: true),
            ),
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
          if (canCancel)
            erpActionButton(
              label: 'Cancel Purchase Order',
              icon: Icons.cancel_outlined,
              onPressed: () => _cancelPo(detail.id),
            ),
          if (canDelete)
            erpActionButton(
              label: 'Delete Draft',
              icon: Icons.delete_outline_rounded,
              onPressed: () => _deletePo(detail.id, closeSheet: true),
            ),
          if (!canSubmit &&
              !canReceive &&
              !canBill &&
              !canEdit &&
              !canCancel &&
              !canDelete)
            const Text(
              'No workflow actions available for this document.',
              style: TextStyle(fontSize: 12, color: AppColors.slate),
            ),
        ],
      ),
    );
  }

  bool _matchesAdvancedFilters(PurchaseOrder order) {
    final supplier = _advancedSupplier.trim().toLowerCase();
    if (supplier.isNotEmpty && !order.vendor.toLowerCase().contains(supplier)) {
      return false;
    }
    if (_advancedMinValue != null && order.totalValue < _advancedMinValue!) {
      return false;
    }
    if (_advancedMaxValue != null && order.totalValue > _advancedMaxValue!) {
      return false;
    }

    final date = _parseDate(order.eta);
    if (_advancedFrom != null &&
        (date == null || date.isBefore(_dateOnly(_advancedFrom!)))) {
      return false;
    }
    if (_advancedTo != null &&
        (date == null || date.isAfter(_dateOnly(_advancedTo!)))) {
      return false;
    }

    final item = _advancedItem.trim().toLowerCase();
    if (item.isNotEmpty &&
        !order.items.any(
          (row) =>
              row.itemCode.toLowerCase().contains(item) ||
              row.itemName.toLowerCase().contains(item),
        )) {
      return false;
    }

    final warehouse = _advancedWarehouse.trim().toLowerCase();
    if (warehouse.isNotEmpty &&
        !order.items.any(
          (row) => row.warehouse.toLowerCase().contains(warehouse),
        )) {
      return false;
    }

    return switch (_advancedDocStatus) {
      _PoDocStatusFilter.all => true,
      _PoDocStatusFilter.draft => order.docStatus == 0,
      _PoDocStatusFilter.submitted => order.docStatus == 1,
      _PoDocStatusFilter.cancelled => order.docStatus == 2,
    };
  }

  int get _advancedFilterCount {
    var count = 0;
    if (_advancedSupplier.trim().isNotEmpty) count++;
    if (_advancedItem.trim().isNotEmpty) count++;
    if (_advancedWarehouse.trim().isNotEmpty) count++;
    if (_advancedMinValue != null) count++;
    if (_advancedMaxValue != null) count++;
    if (_advancedFrom != null || _advancedTo != null) count++;
    if (_advancedDocStatus != _PoDocStatusFilter.all) count++;
    return count;
  }

  Future<void> _editPo(String id, {bool closeSheet = false}) async {
    if (closeSheet) Navigator.pop(context);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatePurchaseOrderScreen(editOrderId: id),
      ),
    );
    if (mounted) {
      await context.read<AppState>().refreshPurchaseOrders();
    }
  }

  Future<void> _submitPo(String id) async {
    if (!await confirmErpAction(
      context,
      title: 'Submit Purchase Order?',
      message: 'Submit $id?',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await runErpWorkflowAction(
      context,
      action: () =>
          context.read<AppState>().submitDocument('Purchase Order', id),
      successMessage: 'Purchase Order submitted',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _cancelPo(String id) async {
    if (!await confirmErpAction(
      context,
      title: 'Cancel Purchase Order?',
      message: 'Batalkan $id?',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await runErpWorkflowAction(
      context,
      action: () =>
          context.read<AppState>().cancelDocument('Purchase Order', id),
      successMessage: 'Purchase Order cancelled',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _deletePo(String id, {bool closeSheet = false}) async {
    if (!await confirmErpAction(
      context,
      title: 'Delete Draft Purchase Order?',
      message: 'Hapus draft $id?',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await runErpWorkflowAction(
      context,
      action: () => context.read<AppState>().deletePurchaseOrder(id),
      successMessage: 'Purchase Order deleted',
    );
    if (ok && mounted && closeSheet) Navigator.pop(context);
  }

  Future<void> _createPr(String poId) async {
    final ok = await runErpWorkflowAction(
      context,
      action: () =>
          context.read<AppState>().createPurchaseReceiptFromPurchaseOrder(poId),
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
      action: () =>
          context.read<AppState>().createPurchaseInvoiceFromPurchaseOrder(poId),
      successMessage: 'Purchase Invoice created',
    );
    if (ok && mounted) {
      Navigator.pop(context);
      await context.read<AppState>().refreshPurchaseInvoices();
    }
  }

  List<Widget> _workflowButtons({
    required String doctype,
    required String name,
    required List<String> actions,
  }) {
    return actions.map((action) {
      final lower = action.toLowerCase();
      final needsReason =
          lower.contains('reject') ||
          lower.contains('tolak') ||
          lower.contains('decline') ||
          lower.contains('return');
      final isApprove =
          lower.contains('approve') ||
          lower.contains('submit') ||
          lower.contains('confirm');
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: erpActionButton(
          label: action,
          icon: needsReason
              ? Icons.cancel_outlined
              : isApprove
              ? Icons.verified_outlined
              : Icons.route_outlined,
          filled: isApprove && !needsReason,
          onPressed: () => _applyWorkflowAction(
            doctype: doctype,
            name: name,
            action: action,
            needsReason: needsReason,
          ),
        ),
      );
    }).toList();
  }

  Future<void> _applyWorkflowAction({
    required String doctype,
    required String name,
    required String action,
    required bool needsReason,
  }) async {
    var reason = '';
    if (needsReason) {
      reason = await _askReason(action) ?? '';
      if (reason.trim().isEmpty) return;
      if (!mounted) return;
    } else {
      final ok = await confirmErpAction(
        context,
        title: '$action $name?',
        message: 'Lanjutkan action "$action" untuk $name?',
      );
      if (!ok || !mounted) return;
    }

    final ok = await runErpWorkflowAction(
      context,
      action: () => context.read<AppState>().applyDocumentWorkflow(
        doctype: doctype,
        name: name,
        action: action,
        reason: reason,
      ),
      successMessage: '$action berhasil',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  Future<String?> _askReason(String action) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action - alasan wajib'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Alasan',
            hintText: 'Tulis alasan agar tercatat di ERPNext',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = _filter(appState.purchaseOrders);
    final overdueCount = appState.purchaseOrders
        .where((o) => o.isOverdue)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ErpSummaryCard(
          title: 'Purchase Orders',
          valueLabel: 'orders',
          totalValue: appState.purchaseOrderSummary.totalValue,
          documentCount: appState.purchaseOrderSummary.documentCount,
          subtitle:
              '${appState.summarySyncSubtitle} | ${filtered.length} loaded'
              '${overdueCount > 0 ? ' | $overdueCount overdue' : ''}',
          isLoading:
              appState.isOrderSummaryLoading &&
              appState.purchaseOrderSummary.documentCount == 0,
        ),
        const SizedBox(height: 12),
        DocumentTrendCard(
          title: 'Purchase Order',
          emptyMessage: 'Belum ada Purchase Order aktif pada periode ini.',
          points: appState.purchaseOrderTrendPoints,
          selectedYear: appState.buyingPeriodYear,
          selectedMonth: appState.buyingPeriodMonth,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          onChanged: _searchChanged,
          decoration: InputDecoration(
            hintText: 'Search PO or supplier…',
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
        if (appState.purchaseOrdersError != null) ...[
          const SizedBox(height: 10),
          ErpErrorBox(message: appState.purchaseOrdersError!),
        ],
        const SizedBox(height: 10),
        _PurchaseOrderQuickFilters(
          sortOption: _sortOption,
          sortLabel: _sortLabel,
          onSortChanged: (v) => setState(() => _sortOption = v),
          onReset: () {
            setState(() {
              _searchController.clear();
              _search = '';
              _statusFilter = null;
              _sortOption = _PurchaseSortOption.newestEta;
              _advancedSupplier = '';
              _advancedItem = '';
              _advancedWarehouse = '';
              _advancedMinValue = null;
              _advancedMaxValue = null;
              _advancedFrom = null;
              _advancedTo = null;
              _advancedDocStatus = _PoDocStatusFilter.all;
            });
            context.read<AppState>().setPurchaseOrderQuery(
              search: '',
              status: null,
            );
          },
          advancedCount: _advancedFilterCount,
          onAdvancedFilters: _openAdvancedFilters,
        ),
        const SizedBox(height: 10),
        ErpStatusChipBar<PurchaseOrderStatusKey?>(
          chips: _chips,
          selected: _statusFilter,
          onSelected: (v) {
            setState(() => _statusFilter = v);
            context.read<AppState>().setPurchaseOrderQuery(
              search: _search,
              status: _statusText,
            );
          },
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty && !appState.isPurchaseOrdersLoading)
          const ErpEmptyState(title: 'No purchase orders found')
        else
          ...filtered.map(
            (o) => ErpDocumentCard(
              id: o.id,
              party: o.vendor,
              statusText: o.statusText,
              date: o.eta,
              value: o.totalValue,
              onTap: () => _openDetail(o),
              onEdit: isDocDraft(o.docStatus) ? () => _editPo(o.id) : null,
              onDelete: isDocDraft(o.docStatus) ? () => _deletePo(o.id) : null,
            ),
          ),
        if (appState.hasMorePurchaseOrders ||
            appState.isMorePurchaseOrdersLoading) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: appState.isMorePurchaseOrdersLoading
                  ? null
                  : () => context.read<AppState>().loadMorePurchaseOrders(),
              icon: appState.isMorePurchaseOrdersLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(
                appState.isMorePurchaseOrdersLoading
                    ? 'Loading orders...'
                    : 'Load more orders',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PurchaseOrderQuickFilters extends StatelessWidget {
  final _PurchaseSortOption sortOption;
  final String Function(_PurchaseSortOption) sortLabel;
  final ValueChanged<_PurchaseSortOption> onSortChanged;
  final VoidCallback onReset;
  final int advancedCount;
  final VoidCallback onAdvancedFilters;

  const _PurchaseOrderQuickFilters({
    required this.sortOption,
    required this.sortLabel,
    required this.onSortChanged,
    required this.onReset,
    required this.advancedCount,
    required this.onAdvancedFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<_PurchaseSortOption>(
              initialValue: sortOption,
              decoration: const InputDecoration(
                labelText: 'Urutkan',
                prefixIcon: Icon(Icons.sort_rounded, size: 18),
              ),
              items: _PurchaseSortOption.values.map((option) {
                return DropdownMenuItem<_PurchaseSortOption>(
                  value: option,
                  child: Text(sortLabel(option)),
                );
              }).toList(),
              onChanged: (option) {
                if (option != null) onSortChanged(option);
              },
            ),
          ),
          const SizedBox(width: 8),
          _PurchaseFilterButton(
            icon: Icons.tune_rounded,
            label: advancedCount > 0 ? 'Filter $advancedCount' : 'Filter',
            onTap: onAdvancedFilters,
          ),
          const SizedBox(width: 8),
          _PurchaseFilterButton(
            icon: Icons.restart_alt_rounded,
            label: 'Reset',
            onTap: onReset,
          ),
        ],
      ),
    );
  }
}

class _PurchaseFilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PurchaseFilterButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.softGreen,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 64,
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplierPriceComparisonCard extends StatelessWidget {
  final PurchaseOrder order;
  final List<Map<String, dynamic>> priceRows;

  const _SupplierPriceComparisonCard({
    required this.order,
    required this.priceRows,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.compare_arrows_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Supplier Price Comparison',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows.map((row) => _comparisonRow(row)),
        ],
      ),
    );
  }

  List<_PriceComparisonRow> _rows() {
    return order.items
        .map((item) {
          final candidates =
              priceRows
                  .where((row) => row['item_code']?.toString() == item.itemCode)
                  .map(_PriceCandidate.fromJson)
                  .where((row) => row.rate > 0)
                  .toList()
                ..sort((a, b) => a.rate.compareTo(b.rate));
          if (candidates.isEmpty) return null;
          return _PriceComparisonRow(item: item, best: candidates.first);
        })
        .whereType<_PriceComparisonRow>()
        .toList();
  }

  Widget _comparisonRow(_PriceComparisonRow row) {
    final delta = row.item.rate - row.best.rate;
    final isHigher = delta > 0;
    final isLower = delta < 0;
    final color = isHigher
        ? AppColors.danger
        : isLower
        ? AppColors.success
        : AppColors.slate;
    final label = isHigher
        ? 'PO lebih tinggi Rp ${formatErpCurrency(delta)}'
        : isLower
        ? 'PO lebih rendah Rp ${formatErpCurrency(delta.abs())}'
        : 'Sama dengan referensi';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.item.itemName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              [
                'PO Rp ${formatErpCurrency(row.item.rate)}',
                'Ref Rp ${formatErpCurrency(row.best.rate)}',
                row.best.source,
              ].where((text) => text.trim().isNotEmpty).join(' | '),
              style: const TextStyle(color: AppColors.slate, fontSize: 11),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceComparisonRow {
  final PurchaseOrderItem item;
  final _PriceCandidate best;

  const _PriceComparisonRow({required this.item, required this.best});
}

class _PriceCandidate {
  final double rate;
  final String source;

  const _PriceCandidate({required this.rate, required this.source});

  factory _PriceCandidate.fromJson(Map<String, dynamic> json) {
    final supplier = json['supplier']?.toString() ?? '';
    final priceList = json['price_list']?.toString() ?? '';
    final source = supplier.isNotEmpty ? supplier : priceList;
    return _PriceCandidate(
      rate: double.tryParse(json['price_list_rate']?.toString() ?? '') ?? 0,
      source: source,
    );
  }
}

class _PurchaseOrderAdvancedFilters {
  final String supplier;
  final String item;
  final String warehouse;
  final double? minValue;
  final double? maxValue;
  final DateTime? from;
  final DateTime? to;
  final _PoDocStatusFilter docStatus;

  const _PurchaseOrderAdvancedFilters({
    required this.supplier,
    required this.item,
    required this.warehouse,
    required this.minValue,
    required this.maxValue,
    required this.from,
    required this.to,
    required this.docStatus,
  });
}

class _PurchaseOrderAdvancedFilterSheet extends StatefulWidget {
  final _PurchaseOrderAdvancedFilters initial;

  const _PurchaseOrderAdvancedFilterSheet({required this.initial});

  @override
  State<_PurchaseOrderAdvancedFilterSheet> createState() =>
      _PurchaseOrderAdvancedFilterSheetState();
}

class _PurchaseOrderAdvancedFilterSheetState
    extends State<_PurchaseOrderAdvancedFilterSheet> {
  late final TextEditingController _supplierCtrl;
  late final TextEditingController _itemCtrl;
  late final TextEditingController _warehouseCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  DateTime? _from;
  DateTime? _to;
  late _PoDocStatusFilter _docStatus;

  @override
  void initState() {
    super.initState();
    _supplierCtrl = TextEditingController(text: widget.initial.supplier);
    _itemCtrl = TextEditingController(text: widget.initial.item);
    _warehouseCtrl = TextEditingController(text: widget.initial.warehouse);
    _minCtrl = TextEditingController(
      text: widget.initial.minValue?.toStringAsFixed(0) ?? '',
    );
    _maxCtrl = TextEditingController(
      text: widget.initial.maxValue?.toStringAsFixed(0) ?? '',
    );
    _from = widget.initial.from;
    _to = widget.initial.to;
    _docStatus = widget.initial.docStatus;
  }

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _itemCtrl.dispose();
    _warehouseCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  String _dateText(DateTime? date) {
    if (date == null) return 'Any';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      _PurchaseOrderAdvancedFilters(
        supplier: _supplierCtrl.text.trim(),
        item: _itemCtrl.text.trim(),
        warehouse: _warehouseCtrl.text.trim(),
        minValue: double.tryParse(_minCtrl.text.trim()),
        maxValue: double.tryParse(_maxCtrl.text.trim()),
        from: _from,
        to: _to,
        docStatus: _docStatus,
      ),
    );
  }

  void _reset() {
    Navigator.pop(
      context,
      const _PurchaseOrderAdvancedFilters(
        supplier: '',
        item: '',
        warehouse: '',
        minValue: null,
        maxValue: null,
        from: null,
        to: null,
        docStatus: _PoDocStatusFilter.all,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Advanced Purchase Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _supplierCtrl,
                decoration: const InputDecoration(labelText: 'Supplier'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _itemCtrl,
                decoration: const InputDecoration(labelText: 'Item keyword'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _warehouseCtrl,
                decoration: const InputDecoration(labelText: 'Warehouse'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min value'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max value'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isFrom: true),
                      icon: const Icon(Icons.date_range_rounded),
                      label: Text('From ${_dateText(_from)}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isFrom: false),
                      icon: const Icon(Icons.event_rounded),
                      label: Text('To ${_dateText(_to)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<_PoDocStatusFilter>(
                initialValue: _docStatus,
                decoration: const InputDecoration(labelText: 'Doc status'),
                items: const [
                  DropdownMenuItem(
                    value: _PoDocStatusFilter.all,
                    child: Text('All'),
                  ),
                  DropdownMenuItem(
                    value: _PoDocStatusFilter.draft,
                    child: Text('Draft'),
                  ),
                  DropdownMenuItem(
                    value: _PoDocStatusFilter.submitted,
                    child: Text('Submitted'),
                  ),
                  DropdownMenuItem(
                    value: _PoDocStatusFilter.cancelled,
                    child: Text('Cancelled'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _docStatus = value);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reset,
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _apply,
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
