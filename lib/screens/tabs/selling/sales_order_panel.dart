import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/sales_order.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/erp_doc_utils.dart';
import '../../../utils/erp_format.dart';
import '../../../widgets/erp/document_trend_card.dart';
import '../../../widgets/erp/erp_document_card.dart';
import '../../../widgets/erp/erp_detail_sheet.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import '../../../widgets/erp/erp_status_chip_bar.dart';
import '../../../widgets/erp/erp_summary_card.dart';
import '../../../widgets/erp/erp_workflow_helper.dart';
import '../../sales/sales_order/create_sales_order_screen.dart';

enum _OrderSortOption { newest, oldest, valueHigh, valueLow }

enum _DocStatusFilter { all, draft, submitted, cancelled }

class SalesOrderPanel extends StatefulWidget {
  const SalesOrderPanel({super.key});

  @override
  State<SalesOrderPanel> createState() => _SalesOrderPanelState();
}

class _SalesOrderPanelState extends State<SalesOrderPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  SalesOrderStatusKey? _statusFilter;
  _OrderSortOption _sortOption = _OrderSortOption.newest;
  String _advancedCustomer = '';
  String _advancedItem = '';
  String _advancedWarehouse = '';
  double? _advancedMinValue;
  double? _advancedMaxValue;
  DateTime? _advancedFrom;
  DateTime? _advancedTo;
  _DocStatusFilter _advancedDocStatus = _DocStatusFilter.all;
  Timer? _searchDebounce;

  static final _chips = <ErpStatusChip<SalesOrderStatusKey?>>[
    const ErpStatusChip(label: 'All', value: null),
    const ErpStatusChip(label: 'Draft', value: SalesOrderStatusKey.draft),
    const ErpStatusChip(label: 'On Hold', value: SalesOrderStatusKey.onHold),
    const ErpStatusChip(label: 'Overdue', value: SalesOrderStatusKey.overdue),
    const ErpStatusChip(
      label: 'Deliver & Bill',
      value: SalesOrderStatusKey.toDeliverAndBill,
    ),
    const ErpStatusChip(label: 'To Bill', value: SalesOrderStatusKey.toBill),
    const ErpStatusChip(
      label: 'To Deliver',
      value: SalesOrderStatusKey.toDeliver,
    ),
    const ErpStatusChip(
      label: 'Completed',
      value: SalesOrderStatusKey.completed,
    ),
    const ErpStatusChip(label: 'Closed', value: SalesOrderStatusKey.closed),
    const ErpStatusChip(
      label: 'Cancelled',
      value: SalesOrderStatusKey.cancelled,
    ),
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    setState(() => _search = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        context.read<AppState>().setSalesOrderQuery(
          search: value,
          status: _statusText,
        );
      }
    });
  }

  String? get _statusText => switch (_statusFilter) {
    SalesOrderStatusKey.draft => 'Draft',
    SalesOrderStatusKey.onHold => 'On Hold',
    SalesOrderStatusKey.overdue => 'Overdue',
    SalesOrderStatusKey.toDeliverAndBill => 'To Deliver and Bill',
    SalesOrderStatusKey.toBill => 'To Bill',
    SalesOrderStatusKey.toDeliver => 'To Deliver',
    SalesOrderStatusKey.completed => 'Completed',
    SalesOrderStatusKey.closed => 'Closed',
    SalesOrderStatusKey.cancelled => 'Cancelled',
    _ => null,
  };

  List<SalesOrder> _filter(List<SalesOrder> orders) {
    final q = _search.toLowerCase();
    final filtered = orders.where((o) {
      final matchSearch =
          q.isEmpty ||
          o.id.toLowerCase().contains(q) ||
          o.customer.toLowerCase().contains(q);
      final matchStatus = _statusFilter == null || o.statusKey == _statusFilter;
      return matchSearch && matchStatus && _matchesAdvancedFilters(o);
    }).toList();

    filtered.sort((a, b) {
      return switch (_sortOption) {
        _OrderSortOption.newest => _compareDateDesc(a.date, b.date),
        _OrderSortOption.oldest => _compareDateAsc(a.date, b.date),
        _OrderSortOption.valueHigh => b.value.compareTo(a.value),
        _OrderSortOption.valueLow => a.value.compareTo(b.value),
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

  String _sortLabel(_OrderSortOption option) {
    return switch (option) {
      _OrderSortOption.newest => 'Newest',
      _OrderSortOption.oldest => 'Oldest',
      _OrderSortOption.valueHigh => 'Value high',
      _OrderSortOption.valueLow => 'Value low',
    };
  }

  Future<void> _openAdvancedFilters() async {
    final result = await showModalBottomSheet<_SalesOrderAdvancedFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return _SalesOrderAdvancedFilterSheet(
          initial: _SalesOrderAdvancedFilters(
            customer: _advancedCustomer,
            item: _advancedItem,
            warehouse: _advancedWarehouse,
            minValue: _advancedMinValue,
            maxValue: _advancedMaxValue,
            from: _advancedFrom,
            to: _advancedTo,
            docStatus: _advancedDocStatus,
          ),
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() {
      _advancedCustomer = result.customer;
      _advancedItem = result.item;
      _advancedWarehouse = result.warehouse;
      _advancedMinValue = result.minValue;
      _advancedMaxValue = result.maxValue;
      _advancedFrom = result.from;
      _advancedTo = result.to;
      _advancedDocStatus = result.docStatus;
    });
  }

  Future<void> _openDetail(SalesOrder order) async {
    final appState = context.read<AppState>();
    final detail = await appState.loadSalesOrderDetail(order.id);
    if (!mounted) return;

    final relatedDn = await appState.fetchDeliveryNotesForSalesOrder(order.id);
    final relatedSi = await appState.fetchSalesInvoicesForSalesOrder(order.id);
    if (!mounted) return;

    final canSubmit = isDocDraft(detail.docStatus);
    final canEdit = isDocDraft(detail.docStatus);

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
          if (canEdit)
            erpActionButton(
              label: 'Edit Sales Order',
              icon: Icons.edit_outlined,
              onPressed: () => _editSo(detail.id, closeSheet: true),
            ),
          if (canSubmit)
            erpActionButton(
              label: 'Submit Sales Order',
              icon: Icons.check_circle_outline_rounded,
              filled: true,
              onPressed: () => _submitSo(detail.id),
            ),
          if (!canSubmit && !canEdit)
            const Text(
              'No workflow actions available for this document.',
              style: TextStyle(fontSize: 12, color: AppColors.slate),
            ),
        ],
      ),
    );
  }

  bool _matchesAdvancedFilters(SalesOrder order) {
    final customer = _advancedCustomer.trim().toLowerCase();
    if (customer.isNotEmpty &&
        !order.customer.toLowerCase().contains(customer)) {
      return false;
    }

    if (_advancedMinValue != null && order.value < _advancedMinValue!) {
      return false;
    }
    if (_advancedMaxValue != null && order.value > _advancedMaxValue!) {
      return false;
    }

    final date = _parseDate(order.date);
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
      _DocStatusFilter.all => true,
      _DocStatusFilter.draft => order.docStatus == 0,
      _DocStatusFilter.submitted => order.docStatus == 1,
      _DocStatusFilter.cancelled => order.docStatus == 2,
    };
  }

  int get _advancedFilterCount {
    var count = 0;
    if (_advancedCustomer.trim().isNotEmpty) count++;
    if (_advancedItem.trim().isNotEmpty) count++;
    if (_advancedWarehouse.trim().isNotEmpty) count++;
    if (_advancedMinValue != null) count++;
    if (_advancedMaxValue != null) count++;
    if (_advancedFrom != null || _advancedTo != null) count++;
    if (_advancedDocStatus != _DocStatusFilter.all) count++;
    return count;
  }

  Future<void> _editSo(String id, {bool closeSheet = false}) async {
    if (closeSheet) Navigator.pop(context);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateSalesOrderScreen(editOrderId: id),
      ),
    );
    if (mounted) {
      await context.read<AppState>().refreshSalesOrders();
    }
  }

  Future<void> _submitSo(String id) async {
    if (!await confirmErpAction(
      context,
      title: 'Submit Sales Order?',
      message: 'Submit $id to ERPNext?',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await runErpWorkflowAction(
      context,
      action: () => context.read<AppState>().submitDocument('Sales Order', id),
      successMessage: 'Sales Order submitted',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = _filter(appState.salesOrders);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ErpSummaryCard(
          title: 'Sales Orders',
          valueLabel: 'orders',
          totalValue: appState.salesOrderSummary.totalValue,
          documentCount: appState.salesOrderSummary.documentCount,
          subtitle:
              '${appState.summarySyncSubtitle} | '
              '${filtered.length} loaded for current filters',
          isLoading:
              appState.isOrderSummaryLoading &&
              appState.salesOrderSummary.documentCount == 0,
        ),

        const SizedBox(height: 12),

        DocumentTrendCard(
          title: 'Pendapatan',
          emptyMessage: 'Belum ada Sales Order aktif pada periode ini.',
          points: appState.salesOrderTrendPoints,
          selectedYear: appState.sellingPeriodYear,
          selectedMonth: appState.sellingPeriodMonth,
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _searchController,
          onChanged: _searchChanged,
          decoration: InputDecoration(
            hintText: 'Search SO or customer…',
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
        if (appState.salesOrdersError != null) ...[
          const SizedBox(height: 10),
          ErpErrorBox(message: appState.salesOrdersError!),
        ],
        const SizedBox(height: 10),
        _SalesOrderQuickFilters(
          sortOption: _sortOption,
          sortLabel: _sortLabel,
          onSortChanged: (v) => setState(() => _sortOption = v),
          onReset: () {
            setState(() {
              _searchController.clear();
              _search = '';
              _statusFilter = null;
              _sortOption = _OrderSortOption.newest;
              _advancedCustomer = '';
              _advancedItem = '';
              _advancedWarehouse = '';
              _advancedMinValue = null;
              _advancedMaxValue = null;
              _advancedFrom = null;
              _advancedTo = null;
              _advancedDocStatus = _DocStatusFilter.all;
            });
            context.read<AppState>().setSalesOrderQuery(
              search: '',
              status: null,
            );
          },
          advancedCount: _advancedFilterCount,
          onAdvancedFilters: _openAdvancedFilters,
        ),
        const SizedBox(height: 10),
        ErpStatusChipBar<SalesOrderStatusKey?>(
          chips: _chips,
          selected: _statusFilter,
          onSelected: (v) {
            setState(() => _statusFilter = v);
            context.read<AppState>().setSalesOrderQuery(
              search: _search,
              status: _statusText,
            );
          },
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
              onEdit: isDocDraft(o.docStatus) ? () => _editSo(o.id) : null,
            ),
          ),
        if (appState.hasMoreSalesOrders ||
            appState.isMoreSalesOrdersLoading) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: appState.isMoreSalesOrdersLoading
                  ? null
                  : () => context.read<AppState>().loadMoreSalesOrders(),
              icon: appState.isMoreSalesOrdersLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(
                appState.isMoreSalesOrdersLoading
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

class _SalesOrderQuickFilters extends StatelessWidget {
  final _OrderSortOption sortOption;
  final String Function(_OrderSortOption) sortLabel;
  final ValueChanged<_OrderSortOption> onSortChanged;
  final VoidCallback onReset;
  final int advancedCount;
  final VoidCallback onAdvancedFilters;

  const _SalesOrderQuickFilters({
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
            child: DropdownButtonFormField<_OrderSortOption>(
              initialValue: sortOption,
              decoration: const InputDecoration(
                labelText: 'Urutkan',
                prefixIcon: Icon(Icons.sort_rounded, size: 18),
              ),
              items: _OrderSortOption.values.map((option) {
                return DropdownMenuItem<_OrderSortOption>(
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
          _SalesFilterButton(
            icon: Icons.tune_rounded,
            label: advancedCount > 0 ? 'Filter $advancedCount' : 'Filter',
            onTap: onAdvancedFilters,
          ),
          const SizedBox(width: 8),
          _SalesFilterButton(
            icon: Icons.restart_alt_rounded,
            label: 'Reset',
            onTap: onReset,
          ),
        ],
      ),
    );
  }
}

class _SalesFilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SalesFilterButton({
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

class _SalesOrderAdvancedFilters {
  final String customer;
  final String item;
  final String warehouse;
  final double? minValue;
  final double? maxValue;
  final DateTime? from;
  final DateTime? to;
  final _DocStatusFilter docStatus;

  const _SalesOrderAdvancedFilters({
    required this.customer,
    required this.item,
    required this.warehouse,
    required this.minValue,
    required this.maxValue,
    required this.from,
    required this.to,
    required this.docStatus,
  });
}

class _SalesOrderAdvancedFilterSheet extends StatefulWidget {
  final _SalesOrderAdvancedFilters initial;

  const _SalesOrderAdvancedFilterSheet({required this.initial});

  @override
  State<_SalesOrderAdvancedFilterSheet> createState() =>
      _SalesOrderAdvancedFilterSheetState();
}

class _SalesOrderAdvancedFilterSheetState
    extends State<_SalesOrderAdvancedFilterSheet> {
  late final TextEditingController _customerCtrl;
  late final TextEditingController _itemCtrl;
  late final TextEditingController _warehouseCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  DateTime? _from;
  DateTime? _to;
  late _DocStatusFilter _docStatus;

  @override
  void initState() {
    super.initState();
    _customerCtrl = TextEditingController(text: widget.initial.customer);
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
    _customerCtrl.dispose();
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
      _SalesOrderAdvancedFilters(
        customer: _customerCtrl.text.trim(),
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
      const _SalesOrderAdvancedFilters(
        customer: '',
        item: '',
        warehouse: '',
        minValue: null,
        maxValue: null,
        from: null,
        to: null,
        docStatus: _DocStatusFilter.all,
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
                'Advanced Sales Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _customerCtrl,
                decoration: const InputDecoration(labelText: 'Customer'),
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
              DropdownButtonFormField<_DocStatusFilter>(
                initialValue: _docStatus,
                decoration: const InputDecoration(labelText: 'Doc status'),
                items: const [
                  DropdownMenuItem(
                    value: _DocStatusFilter.all,
                    child: Text('All'),
                  ),
                  DropdownMenuItem(
                    value: _DocStatusFilter.draft,
                    child: Text('Draft'),
                  ),
                  DropdownMenuItem(
                    value: _DocStatusFilter.submitted,
                    child: Text('Submitted'),
                  ),
                  DropdownMenuItem(
                    value: _DocStatusFilter.cancelled,
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
