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
import '../../create_purchase_order_screen.dart';

enum _PurchaseDateFilter { all, today, last7Days, monthToDate, last30Days }

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
  bool _delayedOnly = false;
  _PurchaseDateFilter _dateFilter = _PurchaseDateFilter.all;
  _PurchaseSortOption _sortOption = _PurchaseSortOption.newestEta;
  String _advancedSupplier = '';
  String _advancedItem = '';
  String _advancedWarehouse = '';
  double? _advancedMinValue;
  double? _advancedMaxValue;
  DateTime? _advancedFrom;
  DateTime? _advancedTo;
  _PoDocStatusFilter _advancedDocStatus = _PoDocStatusFilter.all;

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
    const ErpStatusChip(label: 'To Pay', value: PurchaseOrderStatusKey.toPay),
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
    const ErpStatusChip(
      label: 'Delayed',
      value: PurchaseOrderStatusKey.delayed,
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
    _searchController.dispose();
    super.dispose();
  }

  List<PurchaseOrder> _filter(List<PurchaseOrder> orders) {
    final q = _search.toLowerCase();
    final filtered = orders.where((o) {
      final matchSearch =
          q.isEmpty ||
          o.id.toLowerCase().contains(q) ||
          o.vendor.toLowerCase().contains(q);
      final matchDate = _matchesDateFilter(o.eta);
      if (_delayedOnly) return matchSearch && matchDate && o.isDelayed;
      final matchStatus = _statusFilter == null || o.statusKey == _statusFilter;
      return matchSearch &&
          matchStatus &&
          matchDate &&
          _matchesAdvancedFilters(o);
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

  bool _matchesDateFilter(String rawDate) {
    if (_dateFilter == _PurchaseDateFilter.all) return true;

    final date = _parseDate(rawDate);
    if (date == null) return false;

    final today = _dateOnly(DateTime.now());
    final value = _dateOnly(date);
    final from = switch (_dateFilter) {
      _PurchaseDateFilter.all => DateTime(1900),
      _PurchaseDateFilter.today => today,
      _PurchaseDateFilter.last7Days => today.subtract(const Duration(days: 6)),
      _PurchaseDateFilter.monthToDate => DateTime(today.year, today.month, 1),
      _PurchaseDateFilter.last30Days => today.subtract(
        const Duration(days: 29),
      ),
    };

    return !value.isBefore(from) && !value.isAfter(today);
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

  String _dateFilterLabel(_PurchaseDateFilter filter) {
    return switch (filter) {
      _PurchaseDateFilter.all => 'All dates',
      _PurchaseDateFilter.today => 'Today',
      _PurchaseDateFilter.last7Days => '7 days',
      _PurchaseDateFilter.monthToDate => 'This month',
      _PurchaseDateFilter.last30Days => '30 days',
    };
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
    final detail = await context.read<AppState>().loadPurchaseOrderDetail(
      order.id,
    );
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

    showErpDetailSheet(
      context: context,
      title: detail.id,
      subtitle: detail.vendor,
      statusText: detail.isDelayed ? 'Delayed (ETA)' : detail.statusText,
      rows: [
        docStatusRow(detail.docStatus),
        ErpDetailRow(label: 'ERP Status', value: detail.statusText),
        ErpDetailRow(
          label: 'Expected',
          value: detail.eta.isEmpty ? '—' : detail.eta,
        ),
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
          ...detail.items
              .take(8)
              .map(
                (i) => ErpDetailRow(
                  label: i.itemName,
                  value: '${i.qty} × ${formatErpCurrency(i.rate)}',
                ),
              ),
      ],
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
      message: 'Submit $id to ERPNext?',
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
      message: 'Cancel $id di ERPNext?',
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
      message: 'Delete draft $id dari ERPNext?',
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = _filter(appState.purchaseOrders);
    final total = filtered.fold<double>(0, (s, o) => s + o.totalValue);
    final delayedCount = appState.purchaseOrders
        .where((o) => o.isDelayed)
        .length;

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
          controller: _searchController,
          onChanged: (v) => setState(() => _search = v),
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
          dateFilter: _dateFilter,
          sortOption: _sortOption,
          dateLabel: _dateFilterLabel,
          sortLabel: _sortLabel,
          onDateChanged: (v) => setState(() => _dateFilter = v),
          onSortChanged: (v) => setState(() => _sortOption = v),
          onReset: () => setState(() {
            _searchController.clear();
            _search = '';
            _statusFilter = null;
            _delayedOnly = false;
            _dateFilter = _PurchaseDateFilter.all;
            _sortOption = _PurchaseSortOption.newestEta;
            _advancedSupplier = '';
            _advancedItem = '';
            _advancedWarehouse = '';
            _advancedMinValue = null;
            _advancedMaxValue = null;
            _advancedFrom = null;
            _advancedTo = null;
            _advancedDocStatus = _PoDocStatusFilter.all;
          }),
          advancedCount: _advancedFilterCount,
          onAdvancedFilters: _openAdvancedFilters,
        ),
        const SizedBox(height: 10),
        ErpStatusChipBar<PurchaseOrderStatusKey?>(
          chips: _chips,
          selected: _delayedOnly
              ? PurchaseOrderStatusKey.delayed
              : _statusFilter,
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
  final _PurchaseDateFilter dateFilter;
  final _PurchaseSortOption sortOption;
  final String Function(_PurchaseDateFilter) dateLabel;
  final String Function(_PurchaseSortOption) sortLabel;
  final ValueChanged<_PurchaseDateFilter> onDateChanged;
  final ValueChanged<_PurchaseSortOption> onSortChanged;
  final VoidCallback onReset;
  final int advancedCount;
  final VoidCallback onAdvancedFilters;

  const _PurchaseOrderQuickFilters({
    required this.dateFilter,
    required this.sortOption,
    required this.dateLabel,
    required this.sortLabel,
    required this.onDateChanged,
    required this.onSortChanged,
    required this.onReset,
    required this.advancedCount,
    required this.onAdvancedFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_available_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _PurchaseDateFilter.values.map((filter) {
                      final selected = dateFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(dateLabel(filter)),
                          selected: selected,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.softGreen,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: selected
                                ? AppColors.white
                                : AppColors.primary,
                          ),
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.1),
                          ),
                          onSelected: (_) => onDateChanged(filter),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<_PurchaseSortOption>(
                    value: sortOption,
                    isDense: true,
                    isExpanded: true,
                    dropdownColor: AppColors.white,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primary,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy,
                    ),
                    items: _PurchaseSortOption.values.map((option) {
                      return DropdownMenuItem<_PurchaseSortOption>(
                        value: option,
                        child: Text('Sort: ${sortLabel(option)}'),
                      );
                    }).toList(),
                    onChanged: (option) {
                      if (option != null) onSortChanged(option);
                    },
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onAdvancedFilters,
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: Text(
                  advancedCount > 0 ? 'Filter ($advancedCount)' : 'Filter',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded, size: 17),
                label: const Text('Reset'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
