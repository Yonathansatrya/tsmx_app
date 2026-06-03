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

enum _PurchaseDateFilter { all, today, last7Days, monthToDate, last30Days }

enum _PurchaseSortOption { newestEta, oldestEta, valueHigh, valueLow }

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
      return matchSearch && matchStatus && matchDate;
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

  Future<void> _openDetail(PurchaseOrder order) async {
    final detail = await context.read<AppState>().loadPurchaseOrderDetail(
      order.id,
    );
    if (!mounted) return;

    final canReceive =
        isDocSubmitted(detail.docStatus) && detail.perReceived < 100;
    final canBill = isDocSubmitted(detail.docStatus) && detail.perBilled < 100;
    final canSubmit = isDocDraft(detail.docStatus);

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
          if (!canSubmit && !canReceive && !canBill)
            const Text(
              'No workflow actions available for this document.',
              style: TextStyle(fontSize: 12, color: AppColors.slate),
            ),
        ],
      ),
    );
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
          }),
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
            ),
          ),
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

  const _PurchaseOrderQuickFilters({
    required this.dateFilter,
    required this.sortOption,
    required this.dateLabel,
    required this.sortLabel,
    required this.onDateChanged,
    required this.onSortChanged,
    required this.onReset,
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
