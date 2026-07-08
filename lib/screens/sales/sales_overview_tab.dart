import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sales_workspace.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_range_presets.dart';
import '../../utils/erp_format.dart';
import '../../widgets/erp/erp_empty_state.dart';
import '../../widgets/erp/erp_error_box.dart';
import 'collection/collection_widgets.dart';
import 'sales_ui.dart';

enum _DailySalesDocType { salesOrder, deliveryNote, salesInvoice }

class SalesOverviewTab extends StatefulWidget {
  final ValueChanged<int> onMenuSelected;
  final ValueChanged<int>? onOrderTabSelected;

  const SalesOverviewTab({
    super.key,
    required this.onMenuSelected,
    this.onOrderTabSelected,
  });

  @override
  State<SalesOverviewTab> createState() => _SalesOverviewTabState();
}

class _SalesOverviewTabState extends State<SalesOverviewTab> {
  late DateRangePreset _rankingRange;
  DateTime _dailyReportDate = DateTime.now();
  _DailySalesDocType _dailyDocType = _DailySalesDocType.salesOrder;
  DailySalesReport _dailyReport = const DailySalesReport();
  bool _dailyReportLoading = true;
  String? _dailyReportError;
  List<SalesPersonCustomerRanking> _topCustomers = const [];
  List<CollectionRanking> _ranking = const [];
  bool _topCustomersLoading = true;
  bool _rankingLoading = true;
  String? _topCustomersError;
  String? _rankingError;

  @override
  void initState() {
    super.initState();
    _rankingRange = DateRangePresets.monthToDateRange();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadDailyReport();
      await _loadRanking();
    });
  }

  String get _dailyDoctype => switch (_dailyDocType) {
    _DailySalesDocType.deliveryNote => 'Delivery Note',
    _DailySalesDocType.salesInvoice => 'Sales Invoice',
    _ => 'Sales Order',
  };

  Future<void> _loadDailyReport() async {
    final state = context.read<AppState>();
    if (!state.canUseSales) {
      if (mounted) {
        setState(() {
          _dailyReport = const DailySalesReport();
          _dailyReportLoading = false;
          _dailyReportError = null;
        });
      }
      return;
    }
    setState(() {
      _dailyReportLoading = true;
      _dailyReportError = null;
    });
    try {
      final report = await state.fetchDailySalesReport(
        doctype: _dailyDoctype,
        date: _dailyReportDate,
      );
      if (mounted) setState(() => _dailyReport = report);
    } catch (error) {
      if (mounted) setState(() => _dailyReportError = error.toString());
    } finally {
      if (mounted) setState(() => _dailyReportLoading = false);
    }
  }

  Future<void> _pickDailyReportDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dailyReportDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _dailyReportDate = picked);
    await _loadDailyReport();
  }

  void _setDailyDocType(_DailySalesDocType type) {
    if (_dailyDocType == type) return;
    setState(() => _dailyDocType = type);
    _loadDailyReport();
  }

  Future<void> _loadRanking() async {
    final state = context.read<AppState>();
    final canViewTopCustomers = _canViewTopCustomers(state);
    final canViewRanking = _canViewRanking(state);
    if (!canViewTopCustomers && !canViewRanking) {
      if (mounted) {
        setState(() {
          _topCustomers = const [];
          _ranking = const [];
          _topCustomersLoading = false;
          _rankingLoading = false;
          _topCustomersError = null;
          _rankingError = null;
        });
      }
      return;
    }
    setState(() {
      _topCustomersLoading = canViewTopCustomers;
      _rankingLoading = canViewRanking;
      _topCustomersError = null;
      _rankingError = null;
    });
    if (canViewTopCustomers) {
      try {
        final topCustomers = await state.fetchTopCustomersBySalesPerson(
          from: _rankingRange.from,
          to: _rankingRange.to,
          scopeToCurrentSales: state.mobileAccess.shouldScopeSalesData,
        );
        if (mounted) setState(() => _topCustomers = topCustomers);
      } catch (error) {
        if (mounted) setState(() => _topCustomersError = error.toString());
      } finally {
        if (mounted) setState(() => _topCustomersLoading = false);
      }
    }

    if (canViewRanking) {
      try {
        final ranking = await state.fetchCollectionRanking(
          from: _rankingRange.from,
          to: _rankingRange.to,
        );
        if (mounted) setState(() => _ranking = ranking);
      } catch (error) {
        if (mounted) setState(() => _rankingError = error.toString());
      } finally {
        if (mounted) setState(() => _rankingLoading = false);
      }
    }
  }

  Future<void> _pickRankingRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _rankingRange.from,
        end: _rankingRange.to,
      ),
    );
    if (picked == null) return;
    setState(() {
      _rankingRange = DateRangePreset(from: picked.start, to: picked.end);
    });
    await _loadRanking();
  }

  bool _canViewRanking(AppState state) {
    return state.isSalesManagerRole ||
        state.mobileAccess.isAdministrator ||
        state.mobileAccess.isDeveloper ||
        state.mobileAccess.isCompanyAdministrator ||
        state.mobileAccess.isDirector;
  }

  bool _canViewTopCustomers(AppState state) {
    return state.canUseSales;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final canViewTopCustomers = _canViewTopCustomers(state);
    final canViewRanking = _canViewRanking(state);
    final topCustomerSubtitle = state.mobileAccess.shouldScopeSalesData
        ? 'Customer terbesar milik Sales Person login'
        : 'Customer terbesar dari nilai Sales Order';
    return RefreshIndicator(
      onRefresh: () async {
        await state.refreshDataForCurrentRole();
        await _loadDailyReport();
        await _loadRanking();
      },
      child: ListView(
        padding: SalesUi.screenPadding,
        children: [
          SalesHeroCard(
            title: 'Sales Workspace',
            subtitle: 'Pantau order, stok, customer, collection, dan visit',
            icon: Icons.point_of_sale_rounded,
          ),

          SalesUi.gap(18),

          const SalesSectionTitle(
            title: 'Menu Cepat',
            subtitle: 'Aksi harian yang paling sering dipakai sales',
          ),

          SalesUi.gap(10),

          _QuickMenuGrid(
            items: [
              _QuickMenuItem(
                label: 'Sales Order',
                icon: Icons.receipt_long,
                tap: () {
                  widget.onOrderTabSelected?.call(0);
                  widget.onMenuSelected(1);
                },
              ),
              _QuickMenuItem(
                label: 'Invoice',
                icon: Icons.request_quote_outlined,
                tap: () {
                  widget.onOrderTabSelected?.call(2);
                  widget.onMenuSelected(1);
                },
              ),
              _QuickMenuItem(
                label: 'Collection',
                icon: Icons.account_balance_wallet,
                tap: () => widget.onMenuSelected(2),
              ),
              _QuickMenuItem(
                label: 'Sales Visit',
                icon: Icons.route_rounded,
                tap: () => widget.onMenuSelected(3),
              ),
            ],
          ),

          if (state.canUseSales) ...[
            SalesUi.gap(18),
            _DailySalesReportCard(
              report: _dailyReport,
              loading: _dailyReportLoading,
              error: _dailyReportError,
              selectedType: _dailyDocType,
              selectedDate: _dailyReportDate,
              onTypeChanged: _setDailyDocType,
              onPickDate: _pickDailyReportDate,
            ),
          ],

          if (canViewTopCustomers) ...[
            SalesUi.gap(18),
            CollectionSectionHeader(
              title: 'Top 10 Customer per Sales Person',
              subtitle: topCustomerSubtitle,
              icon: Icons.groups_2_rounded,
              trailing: IconButton.filledTonal(
                tooltip: 'Pilih periode',
                onPressed: _pickRankingRange,
                icon: const Icon(Icons.date_range_rounded),
              ),
            ),
            SalesUi.gap(10),
            if (_topCustomersLoading)
              const LinearProgressIndicator()
            else if (_topCustomersError != null)
              ErpErrorBox(message: _topCustomersError!)
            else if (_topCustomers.isEmpty)
              const ErpEmptyState(
                title: 'Belum ada customer pada periode ini',
                message:
                    'Top customer dibaca dari Sales Team pada Sales Order sesuai periode.',
              )
            else
              ..._topCustomers
                  .take(10)
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TopCustomerCard(row: row),
                    ),
                  ),
          ],

          if (canViewRanking) ...[
            SalesUi.gap(18),
            CollectionSectionHeader(
              title: 'Ranking Collection',
              subtitle: 'Berdasarkan nilai Sales Order dari Sales Team',
              icon: Icons.emoji_events_rounded,
              trailing: IconButton.filledTonal(
                tooltip: 'Pilih periode',
                onPressed: _pickRankingRange,
                icon: const Icon(Icons.date_range_rounded),
              ),
            ),
            SalesUi.gap(10),
            if (_rankingLoading)
              const LinearProgressIndicator()
            else if (_rankingError != null)
              ErpErrorBox(message: _rankingError!)
            else if (_ranking.isEmpty)
              const ErpEmptyState(
                title: 'Belum ada Sales Order pada periode ini',
                message:
                    'Ranking dibaca dari Sales Team pada Sales Order sesuai periode.',
              )
            else
              ..._ranking
                  .take(5)
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SalesInfoCard(
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: row.rank <= 3
                                  ? AppColors.accentYellow.withValues(
                                      alpha: 0.35,
                                    )
                                  : AppColors.softGreen,
                              foregroundColor: AppColors.primaryDark,
                              child: Text(
                                '${row.rank}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                row.salesPerson,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              'Rp ${formatErpCurrency(row.amount)}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ],
        ],
      ),
    );
  }
}

class _DailySalesReportCard extends StatelessWidget {
  const _DailySalesReportCard({
    required this.report,
    required this.loading,
    required this.error,
    required this.selectedType,
    required this.selectedDate,
    required this.onTypeChanged,
    required this.onPickDate,
  });

  final DailySalesReport report;
  final bool loading;
  final String? error;
  final _DailySalesDocType selectedType;
  final DateTime selectedDate;
  final ValueChanged<_DailySalesDocType> onTypeChanged;
  final VoidCallback onPickDate;

  String get _docLabel => switch (selectedType) {
    _DailySalesDocType.deliveryNote => 'DN',
    _DailySalesDocType.salesInvoice => 'SI',
    _ => 'SO',
  };

  @override
  Widget build(BuildContext context) {
    return SalesInfoCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.summarize_rounded,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: 10),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Harian Pendapatan',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ringkasan item dan omzet per customer',
                      style: TextStyle(
                        color: AppColors.slate,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton.filledTonal(
                tooltip: 'Pilih tanggal',
                onPressed: onPickDate,
                icon: const Icon(Icons.event_rounded),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    _DailyDocChip(
                      label: 'SO',
                      selected: selectedType == _DailySalesDocType.salesOrder,
                      onTap: () => onTypeChanged(_DailySalesDocType.salesOrder),
                    ),
                    _DailyDocChip(
                      label: 'DN',
                      selected: selectedType == _DailySalesDocType.deliveryNote,
                      onTap: () =>
                          onTypeChanged(_DailySalesDocType.deliveryNote),
                    ),
                    _DailyDocChip(
                      label: 'SI',
                      selected: selectedType == _DailySalesDocType.salesInvoice,
                      onTap: () =>
                          onTypeChanged(_DailySalesDocType.salesInvoice),
                    ),
                  ],
                ),
              ),

              Text(
                '${selectedDate.day.toString().padLeft(2, '0')}/'
                '${selectedDate.month.toString().padLeft(2, '0')}/'
                '${selectedDate.year}',
                style: const TextStyle(
                  color: AppColors.slate,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (loading)
            const LinearProgressIndicator()
          else if (error != null)
            ErpErrorBox(message: error!)
          else if (report.isEmpty)
            ErpEmptyState(
              title: 'Belum ada data $_docLabel pada tanggal ini',
              message: 'Coba pilih tanggal atau tipe dokumen lain.',
            )
          else ...[
            _DailyItemSummaryTable(report: report),
            const SizedBox(height: 12),
            ...report.customers.map(
              (customer) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DailyCustomerSalesCard(customer: customer),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DailyDocChip extends StatelessWidget {
  const _DailyDocChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? AppColors.white : AppColors.primary,
        fontWeight: FontWeight.w900,
      ),
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
      backgroundColor: AppColors.softGreen,
    );
  }
}

class _DailyItemSummaryTable extends StatelessWidget {
  const _DailyItemSummaryTable({required this.report});

  final DailySalesReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const _DailySummaryRow(
            item: 'Item',
            qty: 'Qty',
            amount: 'Omzet',
            header: true,
          ),
          ...report.items.map(
            (item) => _DailySummaryRow(
              item: item.itemLabel,
              qty: _formatQty(item.qty),
              amount: 'Rp ${formatErpCurrency(item.amount)}',
            ),
          ),
          _DailySummaryRow(
            item: 'TOTAL SALES',
            qty: _formatQty(report.totalQty),
            amount: 'Rp ${formatErpCurrency(report.totalAmount)}',
            total: true,
          ),
        ],
      ),
    );
  }
}

class _DailySummaryRow extends StatelessWidget {
  const _DailySummaryRow({
    required this.item,
    required this.qty,
    required this.amount,
    this.header = false,
    this.total = false,
  });

  final String item;
  final String qty;
  final String amount;
  final bool header;
  final bool total;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: header ? AppColors.slate : AppColors.navy,
      fontSize: 12,
      fontWeight: header || total ? FontWeight.w900 : FontWeight.w700,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: total ? AppColors.softGreen : Colors.transparent,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(item, style: style)),
          Expanded(
            child: Text(qty, textAlign: TextAlign.right, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(amount, textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _DailyCustomerSalesCard extends StatelessWidget {
  const _DailyCustomerSalesCard({required this.customer});

  final DailySalesCustomerSummary customer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            customer.customer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Divider(height: 18),
          ...customer.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.itemLabel,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _formatQty(item.qty),
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Total : Rp ${formatErpCurrency(customer.totalAmount)}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatQty(double value) {
  final fixed = value.truncateToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return fixed.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
}

class _TopCustomerCard extends StatelessWidget {
  const _TopCustomerCard({required this.row});

  final SalesPersonCustomerRanking row;

  @override
  Widget build(BuildContext context) {
    return SalesInfoCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: row.rank <= 3
                ? AppColors.accentYellow.withValues(alpha: 0.35)
                : AppColors.softGreen,
            foregroundColor: AppColors.primaryDark,
            child: Text(
              '${row.rank}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.salesPerson} • ${row.orderCount} SO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Rp ${formatErpCurrency(row.amount)}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback tap;

  const _QuickMenuItem({
    required this.label,
    required this.icon,
    required this.tap,
  });
}

class _QuickMenuGrid extends StatelessWidget {
  final List<_QuickMenuItem> items;

  const _QuickMenuGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final itemWidth = (MediaQuery.sizeOf(context).width - 42) / 2;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [for (final item in items) _Menu(item: item, width: itemWidth)],
    );
  }
}

class _Menu extends StatelessWidget {
  final _QuickMenuItem item;
  final double width;

  const _Menu({required this.item, required this.width});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: SalesInfoCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      onTap: item.tap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(item.icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.slate,
            size: 18,
          ),
        ],
      ),
    ),
  );
}
