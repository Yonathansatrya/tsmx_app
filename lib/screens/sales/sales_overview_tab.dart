import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

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
  DateTime _filterDate = DateTime.now();
  String? _selectedSalesPerson;
  List<String> _salesPersonOptions = const [];
  bool _filterLoading = true;
  _DailySalesDocType _dailyDocType = _DailySalesDocType.salesOrder;
  DailySalesReport _dailyReport = const DailySalesReport();
  bool _dailyReportLoading = true;
  int _dailyRequestVersion = 0;
  String? _dailyReportError;
  List<SalesPersonCustomerRanking> _topCustomers = const [];
  List<CollectionRanking> _ranking = const [];
  bool _topCustomersLoading = true;
  bool _rankingLoading = true;
  int _rankingRequestVersion = 0;
  String? _topCustomersError;
  String? _rankingError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadFilterOptions();
      await _loadDailyReport();
      await _loadRanking();
    });
  }

  String get _dailyDoctype => switch (_dailyDocType) {
    _DailySalesDocType.deliveryNote => 'Delivery Note',
    _DailySalesDocType.salesInvoice => 'Sales Invoice',
    _ => 'Sales Order',
  };

  Future<void> _loadFilterOptions() async {
    final state = context.read<AppState>();
    try {
      if (state.mobileAccess.shouldScopeSalesData) {
        _selectedSalesPerson = state.currentSalesPerson;
        _salesPersonOptions = [
          if (state.currentSalesPerson?.isNotEmpty == true)
            state.currentSalesPerson!,
        ];
      } else {
        final rows = await state.frappeService.fetchResource(
          'Sales Person',
          fields: const ['name'],
          filters: const [
            ['is_group', '=', 0],
            ['enabled', '=', 1],
          ],
          orderBy: 'name asc',
          limit: 500,
        );
        _salesPersonOptions = rows
            .map((row) => row['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList();
      }
    } catch (_) {
      _salesPersonOptions = [
        if (state.currentSalesPerson?.isNotEmpty == true)
          state.currentSalesPerson!,
      ];
    } finally {
      if (mounted) setState(() => _filterLoading = false);
    }
  }

  Future<void> _loadDailyReport() async {
    final requestVersion = ++_dailyRequestVersion;
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
        from: _filterDate,
        to: _filterDate,
        salesPerson: _selectedSalesPerson,
      );
      if (mounted && requestVersion == _dailyRequestVersion) {
        setState(() => _dailyReport = report);
      }
    } catch (error) {
      if (mounted && requestVersion == _dailyRequestVersion) {
        setState(() => _dailyReportError = error.toString());
      }
    } finally {
      if (mounted && requestVersion == _dailyRequestVersion) {
        setState(() => _dailyReportLoading = false);
      }
    }
  }

  Future<void> _pickFilterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _filterDate = picked);
    await _reloadReports();
  }

  void _setDailyDocType(_DailySalesDocType type) {
    if (_dailyDocType == type) return;
    setState(() => _dailyDocType = type);
    _loadDailyReport();
  }

  Future<void> _loadRanking() async {
    final requestVersion = ++_rankingRequestVersion;
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
          from: _filterDate,
          to: _filterDate,
          scopeToCurrentSales: state.mobileAccess.shouldScopeSalesData,
          salesPerson: _selectedSalesPerson,
        );
        if (mounted && requestVersion == _rankingRequestVersion) {
          setState(() => _topCustomers = topCustomers);
        }
      } catch (error) {
        if (mounted && requestVersion == _rankingRequestVersion) {
          setState(() => _topCustomersError = error.toString());
        }
      } finally {
        if (mounted && requestVersion == _rankingRequestVersion) {
          setState(() => _topCustomersLoading = false);
        }
      }
    }

    if (canViewRanking) {
      try {
        final ranking = await state.fetchCollectionRanking(
          from: _filterDate,
          to: _filterDate,
          filterSalesPerson: _selectedSalesPerson,
        );
        if (mounted && requestVersion == _rankingRequestVersion) {
          setState(() => _ranking = ranking);
        }
      } catch (error) {
        if (mounted && requestVersion == _rankingRequestVersion) {
          setState(() => _rankingError = error.toString());
        }
      } finally {
        if (mounted && requestVersion == _rankingRequestVersion) {
          setState(() => _rankingLoading = false);
        }
      }
    }
  }

  Future<void> _reloadReports() async {
    await Future.wait([_loadDailyReport(), _loadRanking()]);
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

  String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }

  Future<void> _shareCsv(String fileName, List<List<Object?>> rows) async {
    if (rows.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada data untuk diexport')),
      );
      return;
    }
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    final csv = rows
        .map((row) => row.map(_csvCell).join(','))
        .join(Platform.lineTerminator);
    await file.writeAsString(csv, flush: true);
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: fileName,
      ),
    );
  }

  String get _dateFileLabel => DateRangePresets.toFrappeDate(_filterDate);

  Future<void> _exportDailyReport() {
    return _shareCsv('sales_report_$_dateFileLabel.csv', [
      ['Tipe Dokumen', _dailyDoctype],
      ['Tanggal', _dateFileLabel],
      ['Sales Person', _selectedSalesPerson ?? 'Semua'],
      [],
      ['Item', 'Qty', 'Omzet'],
      ..._dailyReport.items.map(
        (item) => [item.itemLabel, item.qty, item.amount],
      ),
      ['TOTAL SALES', _dailyReport.totalQty, _dailyReport.totalAmount],
      [],
      ['Customer', 'Item', 'Qty', 'Omzet Customer'],
      ..._dailyReport.customers.expand(
        (customer) => customer.items.map(
          (item) => [
            customer.customer,
            item.itemLabel,
            item.qty,
            customer.totalAmount,
          ],
        ),
      ),
    ]);
  }

  Future<void> _exportTopCustomers() {
    return _shareCsv('top_10_customer_$_dateFileLabel.csv', [
      ['Rank', 'Sales Person', 'Customer', 'Jumlah SO', 'Nilai'],
      ..._topCustomers
          .take(10)
          .map(
            (row) => [
              row.rank,
              row.salesPerson,
              row.customerName,
              row.orderCount,
              row.amount,
            ],
          ),
    ]);
  }

  Future<void> _exportCollectionRanking() {
    return _shareCsv('ranking_collection_$_dateFileLabel.csv', [
      ['Rank', 'Sales Person', 'Nilai'],
      ..._ranking.take(5).map((row) => [row.rank, row.salesPerson, row.amount]),
    ]);
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

          SalesUi.gap(14),
          _SalesOverviewFilterCard(
            date: _filterDate,
            selectedSalesPerson: _selectedSalesPerson,
            salesPersons: _salesPersonOptions,
            lockSalesPerson: state.mobileAccess.shouldScopeSalesData,
            loading: _filterLoading,
            onPickDate: _pickFilterDate,
            onSalesPersonChanged: (salesPerson) {
              setState(() => _selectedSalesPerson = salesPerson);
              _reloadReports();
            },
          ),

          if (state.canUseSales) ...[
            SalesUi.gap(18),
            _DailySalesReportCard(
              report: _dailyReport,
              loading: _dailyReportLoading,
              error: _dailyReportError,
              selectedType: _dailyDocType,
              onTypeChanged: _setDailyDocType,
              onExport: _exportDailyReport,
            ),
          ],

          if (canViewTopCustomers) ...[
            SalesUi.gap(18),
            SalesInfoCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  CollectionSectionHeader(
                    title: 'Top 10 Customer per Sales Person',
                    subtitle: topCustomerSubtitle,
                    icon: Icons.groups_2_rounded,
                    trailing: IconButton.filledTonal(
                      tooltip: 'Export CSV',
                      onPressed: _topCustomersLoading
                          ? null
                          : _exportTopCustomers,
                      icon: const Icon(Icons.file_download_outlined),
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
                        .map((row) => _TopCustomerCard(row: row)),
                ],
              ),
            ),
          ],

          if (canViewRanking) ...[
            SalesUi.gap(18),
            SalesInfoCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  CollectionSectionHeader(
                    title: 'Ranking Collection',
                    subtitle: 'Berdasarkan nilai Sales Order dari Sales Team',
                    icon: Icons.emoji_events_rounded,
                    trailing: IconButton.filledTonal(
                      tooltip: 'Export CSV',
                      onPressed: _rankingLoading
                          ? null
                          : _exportCollectionRanking,
                      icon: const Icon(Icons.file_download_outlined),
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
                        .map((row) => _CollectionRankingRow(row: row)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SalesOverviewFilterCard extends StatelessWidget {
  const _SalesOverviewFilterCard({
    required this.date,
    required this.selectedSalesPerson,
    required this.salesPersons,
    required this.lockSalesPerson,
    required this.loading,
    required this.onPickDate,
    required this.onSalesPersonChanged,
  });

  final DateTime date;
  final String? selectedSalesPerson;
  final List<String> salesPersons;
  final bool lockSalesPerson;
  final bool loading;
  final VoidCallback onPickDate;
  final ValueChanged<String?> onSalesPersonChanged;

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) {
    return SalesInfoCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Filter Sales Overview',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Tanggal',
                prefixIcon: Icon(Icons.event_rounded),
              ),
              child: Text(
                _date(date),
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (lockSalesPerson)
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Sales Person',
                prefixIcon: Icon(Icons.person_rounded),
              ),
              child: Text(
                selectedSalesPerson ?? '-',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: salesPersons.contains(selectedSalesPerson)
                  ? selectedSalesPerson
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Sales Person',
                prefixIcon: Icon(Icons.person_search_rounded),
              ),
              hint: Text(loading ? 'Memuat Sales Person...' : 'Semua Sales'),
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('Semua Sales'),
                ),
                ...salesPersons.map(
                  (salesPerson) => DropdownMenuItem<String>(
                    value: salesPerson,
                    child: Text(salesPerson, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: loading
                  ? null
                  : (value) => onSalesPersonChanged(
                      value?.trim().isEmpty == true ? null : value,
                    ),
            ),
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
    required this.onTypeChanged,
    required this.onExport,
  });

  final DailySalesReport report;
  final bool loading;
  final String? error;
  final _DailySalesDocType selectedType;
  final ValueChanged<_DailySalesDocType> onTypeChanged;
  final VoidCallback onExport;

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
                tooltip: 'Export CSV',
                onPressed: loading ? null : onExport,
                icon: const Icon(Icons.file_download_outlined),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _DailyDocChip(
                  label: 'SO',
                  selected: selectedType == _DailySalesDocType.salesOrder,
                  onTap: () => onTypeChanged(_DailySalesDocType.salesOrder),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DailyDocChip(
                  label: 'DN',
                  selected: selectedType == _DailySalesDocType.deliveryNote,
                  onTap: () => onTypeChanged(_DailySalesDocType.deliveryNote),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DailyDocChip(
                  label: 'SI',
                  selected: selectedType == _DailySalesDocType.salesInvoice,
                  onTap: () => onTypeChanged(_DailySalesDocType.salesInvoice),
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
              title: 'Belum ada data $_docLabel pada periode ini',
              message: 'Coba pilih rentang tanggal atau tipe dokumen lain.',
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
    return Material(
      color: selected ? AppColors.primary : AppColors.softGreen,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  color: AppColors.white,
                  size: 14,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.white : AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
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
                  '${row.salesPerson} | ${row.orderCount} SO',
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

class _CollectionRankingRow extends StatelessWidget {
  const _CollectionRankingRow({required this.row});

  final CollectionRanking row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
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
    );
  }
}
