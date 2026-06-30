import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/erp_summary.dart';
import '../../models/finance_accounting.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_range_presets.dart';
import '../../utils/erp_format.dart';
import '../../utils/num_parse.dart';
import '../../widgets/erp/erp_empty_state.dart';
import '../../widgets/erp/erp_error_box.dart';
import '../../widgets/erp/erp_detail_sheet.dart';
import '../../widgets/erp/erp_filter_tools.dart';
import '../shared/role_main_screen.dart';

class FinanceMainScreen extends StatelessWidget {
  final int initialTabIndex;

  const FinanceMainScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    final isAccounting = initialTabIndex == 3;
    return RoleMainScreen(
      title: isAccounting ? 'Accounting' : 'Finance',
      fallbackUsername: isAccounting ? 'Accounting' : 'Finance',
      initialTabIndex: initialTabIndex,
      onInitialize: (state) async => state.frappeService.ensureLoggedIn(),
      screensBuilder: (_) => const [
        _FinanceWorkspaceTab(initialView: _FinanceView.dashboard),
        _FinanceWorkspaceTab(initialView: _FinanceView.cashBank),
        _FinanceWorkspaceTab(initialView: _FinanceView.receivablePayable),
        _FinanceWorkspaceTab(initialView: _FinanceView.accounting),
      ],
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_outlined),
          selectedIcon: Icon(Icons.account_balance_rounded),
          label: 'Bank',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: 'AR/AP',
        ),
        NavigationDestination(
          icon: Icon(Icons.auto_stories_outlined),
          selectedIcon: Icon(Icons.auto_stories_rounded),
          label: 'Ledger',
        ),
      ],
    );
  }
}

enum _FinanceView { dashboard, cashBank, receivablePayable, accounting }

final _financeFilterStore = _FinanceFilterStore();

class _FinanceFilterStore extends ChangeNotifier {
  _FinanceFilterStore() {
    final now = DateTime.now();
    year = now.year;
    month = now.month;
  }

  late int year;
  late int month;
  String company = '';

  void update({int? year, int? month, String? company}) {
    var changed = false;
    if (year != null && year != this.year) {
      this.year = year;
      changed = true;
    }
    if (month != null && month != this.month) {
      this.month = month;
      changed = true;
    }
    if (company != null && company != this.company) {
      this.company = company;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}

class _FinanceWorkspaceTab extends StatefulWidget {
  final _FinanceView initialView;

  const _FinanceWorkspaceTab({required this.initialView});

  @override
  State<_FinanceWorkspaceTab> createState() => _FinanceWorkspaceTabState();
}

class _FinanceWorkspaceTabState extends State<_FinanceWorkspaceTab> {
  late int _year;
  late int _month;
  String _company = '';
  List<String> _companies = const [];
  FinanceDashboardData _data = const FinanceDashboardData();
  bool _loading = true;
  String? _error;

  DateTime get _from =>
      _month == 0 ? DateTime(_year) : DateTime(_year, _month, 1);
  DateTime get _to =>
      _month == 0 ? DateTime(_year, 12, 31) : DateTime(_year, _month + 1, 0);

  @override
  void initState() {
    super.initState();
    _year = _financeFilterStore.year;
    _month = _financeFilterStore.month;
    _company = _financeFilterStore.company;
    _financeFilterStore.addListener(_syncSharedFilters);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _financeFilterStore.removeListener(_syncSharedFilters);
    super.dispose();
  }

  void _syncSharedFilters() {
    if (!mounted) return;
    if (_year == _financeFilterStore.year &&
        _month == _financeFilterStore.month &&
        _company == _financeFilterStore.company) {
      return;
    }
    setState(() {
      _year = _financeFilterStore.year;
      _month = _financeFilterStore.month;
      _company = _financeFilterStore.company;
    });
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    _year = _financeFilterStore.year;
    _month = _financeFilterStore.month;
    _company = _financeFilterStore.company;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = context.read<AppState>();
      final companies = await _loadCompanies(state);
      var selectedCompany = _company;
      if (selectedCompany.isEmpty && companies.isNotEmpty) {
        selectedCompany = state.preferredCompany(companies) ?? companies.first;
      }
      final data = await _fetchFinanceData(
        state,
        from: _from,
        to: _to,
        company: selectedCompany,
      );
      if (!mounted) return;
      setState(() {
        _companies = companies;
        _company = selectedCompany;
        _data = data;
      });
      _financeFilterStore.update(company: selectedCompany);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<String>> _loadCompanies(AppState state) async {
    final bootCompanies =
        state.mobileBoot?.companies
            .map((company) => company.trim())
            .where((company) => company.isNotEmpty)
            .toList() ??
        const <String>[];
    if (bootCompanies.isNotEmpty) {
      return (bootCompanies.toSet().toList()..sort());
    }
    final rows = await _safeFetchResource(
      state,
      'Company',
      fields: const ['name'],
      orderBy: 'name asc',
      limit: 500,
    );
    return rows
        .map((row) => row['name']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<FinanceDashboardData> _fetchFinanceData(
    AppState state, {
    required DateTime from,
    required DateTime to,
    required String company,
  }) async {
    final fromText = DateRangePresets.toFrappeDate(from);
    final toText = DateRangePresets.toFrappeDate(to);
    final companyFilter = company.trim().isEmpty
        ? const <List<dynamic>>[]
        : [
            ['company', '=', company.trim()],
          ];

    final paymentRows = await _safeFetchResource(
      state,
      'Payment Entry',
      fields: const [
        'name',
        'posting_date',
        'payment_type',
        'party_type',
        'party',
        'party_name',
        'paid_amount',
        'received_amount',
        'base_paid_amount',
        'base_received_amount',
      ],
      filters: [
        ['docstatus', '=', 1],
        ['posting_date', '>=', fromText],
        ['posting_date', '<=', toText],
        ...companyFilter,
      ],
      orderBy: 'posting_date desc, name desc',
      limit: 10000,
    );

    var cashIn = 0.0;
    var cashOut = 0.0;
    var dailyCollection = 0.0;
    final trend = _emptyTrend(_month);
    for (final row in paymentRows) {
      final type = row['payment_type']?.toString() ?? '';
      final amount = NumParse.asDouble(
        type == 'Receive'
            ? row['base_received_amount'] ?? row['received_amount']
            : row['base_paid_amount'] ?? row['paid_amount'],
      );
      if (type == 'Receive') {
        cashIn += amount;
        if (row['party_type']?.toString() == 'Customer') {
          dailyCollection += amount;
        }
        _addTrend(trend, dateRaw: row['posting_date'], amount: amount);
      } else if (type == 'Pay') {
        cashOut += amount;
        _addTrend(trend, dateRaw: row['posting_date'], amount: -amount);
      }
    }

    final arRows = await _safeFetchResource(
      state,
      'Sales Invoice',
      fields: const [
        'name',
        'customer',
        'customer_name',
        'posting_date',
        'due_date',
        'status',
        'outstanding_amount',
      ],
      filters: [
        ['docstatus', '=', 1],
        ['outstanding_amount', '>', 0],
        ...companyFilter,
      ],
      limit: 10000,
    );
    final apRows = await _safeFetchResource(
      state,
      'Purchase Invoice',
      fields: const [
        'name',
        'supplier',
        'supplier_name',
        'posting_date',
        'due_date',
        'status',
        'outstanding_amount',
      ],
      filters: [
        ['docstatus', '=', 1],
        ['outstanding_amount', '>', 0],
        ...companyFilter,
      ],
      limit: 10000,
    );
    final outstandingAr = arRows.fold<double>(
      0,
      (sum, row) => sum + NumParse.asDouble(row['outstanding_amount']),
    );
    final outstandingAp = apRows.fold<double>(
      0,
      (sum, row) => sum + NumParse.asDouble(row['outstanding_amount']),
    );

    final accountRows = await _safeFetchResource(
      state,
      'Account',
      fields: const ['name', 'account_name', 'account_type', 'root_type'],
      filters: [
        ['is_group', '=', 0],
        ...companyFilter,
      ],
      limit: 10000,
    );
    final bankAccounts = accountRows
        .where((row) => row['account_type']?.toString() == 'Bank')
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    final expenseAccounts = accountRows
        .where((row) => row['root_type']?.toString() == 'Expense')
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    final bankBalances = await _accountBalances(
      state,
      accounts: bankAccounts,
      to: to,
      company: company,
    );
    final bankBalance = bankBalances.fold<double>(
      0,
      (sum, row) => sum + row.balance,
    );
    final expenseTotal = await _expenseTotal(
      state,
      accounts: expenseAccounts,
      from: from,
      to: to,
      company: company,
    );
    final expenseEntries = await _expenseEntries(
      state,
      accounts: expenseAccounts,
      from: from,
      to: to,
      company: company,
    );

    final journalRows = await _safeFetchResource(
      state,
      'Journal Entry',
      fields: const [
        'name',
        'title',
        'posting_date',
        'workflow_state',
        'docstatus',
        'total_debit',
      ],
      filters: [
        ['docstatus', '=', 0],
        ...companyFilter,
      ],
      orderBy: 'modified desc',
      limit: 20,
    );

    final ledgerRows = await _safeFetchResource(
      state,
      'GL Entry',
      fields: const [
        'name',
        'posting_date',
        'account',
        'party',
        'voucher_type',
        'voucher_no',
        'debit',
        'credit',
      ],
      filters: [
        ['is_cancelled', '=', 0],
        ['posting_date', '>=', fromText],
        ['posting_date', '<=', toText],
        ...companyFilter,
      ],
      orderBy: 'posting_date desc, creation desc',
      limit: 30,
    );

    final profitLoss = await _loadReportMetrics(
      state,
      reportName: 'Profit and Loss Statement',
      from: from,
      to: to,
      company: company,
      labels: const [
        'Total Income',
        'Total Expense',
        'Net Profit',
        'Profit for the year',
      ],
    );
    final balanceSheet = await _loadReportMetrics(
      state,
      reportName: 'Balance Sheet',
      from: from,
      to: to,
      company: company,
      labels: const ['Total Asset', 'Total Liability', 'Total Equity'],
    );

    return FinanceDashboardData(
      cashIn: cashIn,
      cashOut: cashOut,
      dailyCollection: dailyCollection,
      bankBalance: bankBalance,
      outstandingAr: outstandingAr,
      outstandingAp: outstandingAp,
      expenseTotal: expenseTotal,
      pendingJournalCount: journalRows.length,
      bankBalances: bankBalances,
      journalEntries: journalRows
          .map(FinanceDocumentRow.fromJournalEntry)
          .toList(),
      cashFlowEntries: paymentRows
          .map(FinanceDocumentRow.fromPaymentEntry)
          .toList(),
      arInvoices: arRows
          .map((row) => FinanceDocumentRow.fromInvoice(row, purchase: false))
          .toList(),
      apInvoices: apRows
          .map((row) => FinanceDocumentRow.fromInvoice(row, purchase: true))
          .toList(),
      expenseEntries: expenseEntries
          .map(FinanceDocumentRow.fromExpenseGl)
          .toList(),
      ledgerRows: ledgerRows.map(GeneralLedgerRow.fromJson).toList(),
      profitLoss: profitLoss,
      balanceSheet: balanceSheet,
      cashFlowTrend: trend,
    );
  }

  Future<List<FinanceBankBalance>> _accountBalances(
    AppState state, {
    required List<String> accounts,
    required DateTime to,
    required String company,
  }) async {
    if (accounts.isEmpty) return const [];
    final reportBalances = await _trialBalanceBankBalances(
      state,
      accounts: accounts,
      to: to,
      company: company,
    );
    if (reportBalances.isNotEmpty) return reportBalances;

    final rows = <Map<String, dynamic>>[];
    const pageSize = 5000;
    for (var start = 0; ; start += pageSize) {
      final page = await _safeFetchResource(
        state,
        'GL Entry',
        fields: const ['account', 'debit', 'credit'],
        filters: [
          ['is_cancelled', '=', 0],
          ['posting_date', '<=', DateRangePresets.toFrappeDate(to)],
          if (company.trim().isNotEmpty) ['company', '=', company.trim()],
          ['account', 'in', accounts],
        ],
        limit: pageSize,
        limitStart: start,
      );
      rows.addAll(page);
      if (page.length < pageSize) break;
    }
    final totals = {for (final account in accounts) account: 0.0};
    for (final row in rows) {
      final account = row['account']?.toString() ?? '';
      if (account.isEmpty) continue;
      totals[account] =
          (totals[account] ?? 0) +
          NumParse.asDouble(row['debit']) -
          NumParse.asDouble(row['credit']);
    }
    final result =
        totals.entries
            .map(
              (entry) =>
                  FinanceBankBalance(account: entry.key, balance: entry.value),
            )
            .toList()
          ..sort((a, b) => b.balance.compareTo(a.balance));
    return result;
  }

  Future<List<FinanceBankBalance>> _trialBalanceBankBalances(
    AppState state, {
    required List<String> accounts,
    required DateTime to,
    required String company,
  }) async {
    try {
      final response = await state.frappeService.callMethod(
        'frappe.desk.query_report.run',
        args: {
          'report_name': 'Trial Balance',
          'filters': {
            if (company.trim().isNotEmpty) 'company': company.trim(),
            'from_date': DateRangePresets.toFrappeDate(DateTime(to.year)),
            'to_date': DateRangePresets.toFrappeDate(to),
            'with_period_closing_entry': 1,
            'show_zero_values': 1,
          },
          'ignore_prepared_report': true,
          'are_default_filters': false,
        },
      );
      final report = _queryReportPayload(response);
      final columns = _queryReportColumns(report?['columns']);
      final rows = _queryReportRows(report?['result'] ?? report?['data']);
      final result = <FinanceBankBalance>[];
      for (final raw in rows) {
        final row = _queryReportRowMap(raw, columns);
        final account = _matchingAccount(row, accounts);
        if (account == null) continue;
        final closingBalance = _numberByReportKey(row, const [
          'closing_balance',
          'balance',
        ]);
        final closingDebit = _numberByReportKey(row, const ['closing_debit']);
        final closingCredit = _numberByReportKey(row, const ['closing_credit']);
        final balance =
            closingBalance ?? (closingDebit ?? 0) - (closingCredit ?? 0);
        result.add(FinanceBankBalance(account: account, balance: balance));
      }
      result.sort((a, b) => b.balance.compareTo(a.balance));
      return result;
    } catch (_) {
      return const [];
    }
  }

  Future<double> _expenseTotal(
    AppState state, {
    required List<String> accounts,
    required DateTime from,
    required DateTime to,
    required String company,
  }) async {
    if (accounts.isEmpty) return 0;
    final rows = await _safeFetchResource(
      state,
      'GL Entry',
      fields: const ['account', 'debit', 'credit'],
      filters: [
        ['is_cancelled', '=', 0],
        ['posting_date', '>=', DateRangePresets.toFrappeDate(from)],
        ['posting_date', '<=', DateRangePresets.toFrappeDate(to)],
        if (company.trim().isNotEmpty) ['company', '=', company.trim()],
        ['account', 'in', accounts],
      ],
      limit: 10000,
    );
    return rows.fold<double>(
      0,
      (sum, row) =>
          sum +
          NumParse.asDouble(row['debit']) -
          NumParse.asDouble(row['credit']),
    );
  }

  Future<List<Map<String, dynamic>>> _expenseEntries(
    AppState state, {
    required List<String> accounts,
    required DateTime from,
    required DateTime to,
    required String company,
  }) async {
    if (accounts.isEmpty) return const [];
    return _safeFetchResource(
      state,
      'GL Entry',
      fields: const [
        'name',
        'posting_date',
        'account',
        'voucher_type',
        'voucher_no',
        'debit',
        'credit',
      ],
      filters: [
        ['is_cancelled', '=', 0],
        ['posting_date', '>=', DateRangePresets.toFrappeDate(from)],
        ['posting_date', '<=', DateRangePresets.toFrappeDate(to)],
        if (company.trim().isNotEmpty) ['company', '=', company.trim()],
        ['account', 'in', accounts],
      ],
      orderBy: 'posting_date desc, creation desc',
      limit: 50,
    );
  }

  Future<List<Map<String, dynamic>>> _safeFetchResource(
    AppState state,
    String doctype, {
    required List<String> fields,
    int limit = 10000,
    int limitStart = 0,
    String? orderBy,
    List<List<dynamic>>? filters,
  }) async {
    try {
      return await state.frappeService.fetchResource(
        doctype,
        fields: fields,
        filters: filters,
        orderBy: orderBy,
        limit: limit,
        limitStart: limitStart,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<List<FinanceReportMetric>> _loadReportMetrics(
    AppState state, {
    required String reportName,
    required DateTime from,
    required DateTime to,
    required String company,
    required List<String> labels,
  }) async {
    try {
      final response = await state.frappeService.callMethod(
        'frappe.desk.query_report.run',
        args: {
          'report_name': reportName,
          'filters': {
            'from_date': DateRangePresets.toFrappeDate(from),
            'to_date': DateRangePresets.toFrappeDate(to),
            'period_start_date': DateRangePresets.toFrappeDate(from),
            'period_end_date': DateRangePresets.toFrappeDate(to),
            if (company.trim().isNotEmpty) 'company': company.trim(),
            'filter_based_on': 'Date Range',
            'periodicity': 'Monthly',
            'accumulated_values': 1,
          },
          'ignore_prepared_report': true,
          'are_default_filters': false,
        },
      );
      final report = _queryReportPayload(response);
      final columns = _queryReportColumns(report?['columns']);
      final rows = _queryReportRows(report?['result'] ?? report?['data']);
      final metrics = <FinanceReportMetric>[];
      for (final wanted in labels) {
        final row = rows
            .map((item) => _queryReportRowMap(item, columns))
            .where(
              (item) =>
                  _rowLabel(item).toLowerCase().contains(wanted.toLowerCase()),
            )
            .cast<Map<String, dynamic>?>()
            .firstWhere((item) => item != null, orElse: () => null);
        if (row == null) continue;
        metrics.add(
          FinanceReportMetric(label: wanted, value: _lastNumericValue(row)),
        );
      }
      return metrics;
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic>? _queryReportPayload(dynamic response) {
    if (response is! Map) return null;
    final message = response['message'];
    if (message is Map) return Map<String, dynamic>.from(message);
    return Map<String, dynamic>.from(response);
  }

  List<Map<String, dynamic>> _queryReportColumns(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((column) {
      if (column is String) return {'fieldname': column, 'label': column};
      if (column is Map) return Map<String, dynamic>.from(column);
      return <String, dynamic>{};
    }).toList();
  }

  List<dynamic> _queryReportRows(dynamic raw) => raw is List ? raw : const [];

  Map<String, dynamic> _queryReportRowMap(
    dynamic row,
    List<Map<String, dynamic>> columns,
  ) {
    if (row is Map) return Map<String, dynamic>.from(row);
    if (row is! List) return const {};
    final mapped = <String, dynamic>{};
    for (var i = 0; i < row.length && i < columns.length; i++) {
      final key =
          columns[i]['fieldname']?.toString() ??
          columns[i]['field']?.toString() ??
          columns[i]['label']?.toString() ??
          '';
      if (key.isNotEmpty) mapped[key] = row[i];
    }
    return mapped;
  }

  String _rowLabel(Map<String, dynamic> row) {
    const keys = ['account', 'account_name', 'label', 'name'];
    for (final key in keys) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return row.values.whereType<String>().firstOrNull ?? '';
  }

  double _lastNumericValue(Map<String, dynamic> row) {
    for (final value in row.values.toList().reversed) {
      final number = NumParse.asDouble(value, fallback: double.nan);
      if (!number.isNaN) return number;
    }
    return 0;
  }

  String? _matchingAccount(Map<String, dynamic> row, List<String> accounts) {
    final candidates = <String>{
      _rowLabel(row),
      row['account']?.toString() ?? '',
      row['account_name']?.toString() ?? '',
      row['name']?.toString() ?? '',
    }.map((value) => value.trim()).where((value) => value.isNotEmpty).toList();
    for (final account in accounts) {
      final trimmedAccount = account.trim();
      if (trimmedAccount.isEmpty) continue;
      for (final candidate in candidates) {
        if (candidate == trimmedAccount ||
            candidate.contains(trimmedAccount) ||
            trimmedAccount.contains(candidate)) {
          return trimmedAccount;
        }
      }
    }
    return null;
  }

  double? _numberByReportKey(Map<String, dynamic> row, List<String> keys) {
    for (final entry in row.entries) {
      final normalized = _normalizeReportKey(entry.key);
      if (!keys.any((key) => normalized == key || normalized.contains(key))) {
        continue;
      }
      final number = NumParse.asDouble(entry.value, fallback: double.nan);
      if (!number.isNaN) return number;
    }
    return null;
  }

  String _normalizeReportKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  List<DocumentTrendPoint> _emptyTrend(int month) {
    if (month == 0) {
      const labels = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return [for (final label in labels) DocumentTrendPoint(label: label)];
    }
    return [
      for (var i = 0; i < 4; i++) DocumentTrendPoint(label: 'Minggu ${i + 1}'),
    ];
  }

  void _addTrend(
    List<DocumentTrendPoint> points, {
    required dynamic dateRaw,
    required double amount,
  }) {
    final date = DateTime.tryParse(dateRaw?.toString() ?? '');
    if (date == null || date.year != _year) return;
    final index = _month == 0
        ? date.month - 1
        : ((date.day - 1) ~/ 7).clamp(0, points.length - 1);
    if (index < 0 || index >= points.length) return;
    points[index] = points[index].add(amount);
  }

  void _setPeriod(int year, int month) {
    _financeFilterStore.update(year: year, month: month);
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.initialView) {
      _FinanceView.dashboard => 'Finance Dashboard',
      _FinanceView.cashBank => 'Cash & Bank',
      _FinanceView.receivablePayable => 'Outstanding AR/AP',
      _FinanceView.accounting => 'Accounting',
    };
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
        children: [
          ErpPeriodFilterCard(
            title: title,
            subtitle: 'Data mengikuti periode dan company aktif ERPNext',
            icon: Icons.account_balance_wallet_rounded,
            selectedYear: _year,
            selectedMonth: _month,
            loading: _loading,
            companyOptions: _companies,
            selectedCompany: _company,
            onChanged: _setPeriod,
            onCompanyChanged: (company) {
              _financeFilterStore.update(company: company);
            },
          ),
          const SizedBox(height: 14),
          if (_error != null)
            ErpErrorBox(message: _error!, onRetry: _load)
          else if (_loading)
            const SizedBox.shrink()
          else
            switch (widget.initialView) {
              _FinanceView.dashboard => _DashboardView(data: _data),
              _FinanceView.cashBank => _CashBankView(data: _data),
              _FinanceView.receivablePayable => _ReceivablePayableView(
                data: _data,
              ),
              _FinanceView.accounting => _AccountingView(data: _data),
            },
        ],
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  final FinanceDashboardData data;

  const _DashboardView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MetricGrid(
          metrics: [
            _MetricData(
              'Cash Flow',
              data.netCashFlow,
              Icons.waterfall_chart,
              onTap: () => _showDocumentRows(
                context,
                title: 'Cash Flow Monitoring',
                rows: data.cashFlowEntries,
                emptyTitle: 'Belum ada Payment Entry',
              ),
            ),
            _MetricData(
              'Bank',
              data.bankBalance,
              Icons.account_balance,
              onTap: () => _showBankBalances(context, data.bankBalances),
            ),
            _MetricData(
              'Collection',
              data.dailyCollection,
              Icons.payments,
              onTap: () => _showDocumentRows(
                context,
                title: 'Daily Collection',
                rows: data.cashFlowEntries
                    .where((row) => row.status == 'Receive')
                    .toList(),
                emptyTitle: 'Belum ada collection',
              ),
            ),
            _MetricData(
              'Expense',
              data.expenseTotal,
              Icons.trending_down,
              onTap: () => _showDocumentRows(
                context,
                title: 'Expense Monitoring',
                rows: data.expenseEntries,
                emptyTitle: 'Belum ada expense',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TrendCard(title: 'Cash Flow Monitoring', points: data.cashFlowTrend),
        const SizedBox(height: 12),
        _MetricGrid(
          metrics: [
            _MetricData(
              'Outstanding AR',
              data.outstandingAr,
              Icons.call_received,
              onTap: () => _showDocumentRows(
                context,
                title: 'Outstanding AR',
                rows: data.arInvoices,
                emptyTitle: 'Tidak ada AR outstanding',
              ),
            ),
            _MetricData(
              'Outstanding AP',
              data.outstandingAp,
              Icons.call_made,
              onTap: () => _showDocumentRows(
                context,
                title: 'Outstanding AP',
                rows: data.apInvoices,
                emptyTitle: 'Tidak ada AP outstanding',
              ),
            ),
            _MetricData(
              'Journal Approval',
              data.pendingJournalCount.toDouble(),
              Icons.approval,
              currency: false,
              onTap: () => _showDocumentRows(
                context,
                title: 'Journal Entry Approval',
                rows: data.journalEntries,
                emptyTitle: 'Tidak ada Journal Entry pending',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CashBankView extends StatelessWidget {
  final FinanceDashboardData data;

  const _CashBankView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MetricGrid(
          metrics: [
            _MetricData('Cash In', data.cashIn, Icons.south_west_rounded),
            _MetricData('Cash Out', data.cashOut, Icons.north_east_rounded),
            _MetricData('Net Flow', data.netCashFlow, Icons.swap_vert_rounded),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Bank Balance Monitoring',
          icon: Icons.account_balance_rounded,
          child: data.bankBalances.isEmpty
              ? const ErpEmptyState(
                  title: 'Belum ada rekening bank',
                  message: 'Saldo dihitung dari GL Entry akun bertipe Bank.',
                )
              : Column(
                  children: [
                    for (final bank in data.bankBalances.take(8))
                      _AmountRow(
                        label: bank.account,
                        amount: bank.balance,
                        onTap: () => _showBankBalance(context, bank),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ReceivablePayableView extends StatelessWidget {
  final FinanceDashboardData data;

  const _ReceivablePayableView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MetricGrid(
          metrics: [
            _MetricData('Outstanding AR', data.outstandingAr, Icons.groups),
            _MetricData('Outstanding AP', data.outstandingAp, Icons.storefront),
            _MetricData(
              'Daily Collection',
              data.dailyCollection,
              Icons.payments,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Outstanding AR/AP',
          icon: Icons.receipt_long_rounded,
          child: Column(
            children: [
              _AmountRow(
                label: 'Sales Invoice belum lunas',
                amount: data.outstandingAr,
                onTap: () => _showDocumentRows(
                  context,
                  title: 'Sales Invoice Outstanding',
                  rows: data.arInvoices,
                  emptyTitle: 'Tidak ada AR outstanding',
                ),
              ),
              _AmountRow(
                label: 'Purchase Invoice belum lunas',
                amount: data.outstandingAp,
                onTap: () => _showDocumentRows(
                  context,
                  title: 'Purchase Invoice Outstanding',
                  rows: data.apInvoices,
                  emptyTitle: 'Tidak ada AP outstanding',
                ),
              ),
              _AmountRow(
                label: 'Selisih AR - AP',
                amount: data.outstandingAr - data.outstandingAp,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountingView extends StatelessWidget {
  final FinanceDashboardData data;

  const _AccountingView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionCard(
          title: 'Journal Entry Approval',
          icon: Icons.approval_rounded,
          child: data.journalEntries.isEmpty
              ? const ErpEmptyState(
                  title: 'Tidak ada Journal Entry pending',
                  message: 'Draft journal akan muncul di sini untuk dicek.',
                )
              : Column(
                  children: [
                    for (final row in data.journalEntries.take(6))
                      _DocumentRow(row: row, doctype: 'Journal Entry'),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _ReportSection(title: 'Profit & Loss', rows: data.profitLoss),
        const SizedBox(height: 12),
        _ReportSection(title: 'Balance Sheet', rows: data.balanceSheet),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'General Ledger Monitoring',
          icon: Icons.auto_stories_rounded,
          child: data.ledgerRows.isEmpty
              ? const ErpEmptyState(
                  title: 'Belum ada mutasi ledger',
                  message: 'GL Entry periode ini belum tersedia.',
                )
              : Column(
                  children: [
                    for (final row in data.ledgerRows.take(10))
                      _LedgerRow(row: row),
                  ],
                ),
        ),
      ],
    );
  }
}

void _showDocumentRows(
  BuildContext context, {
  required String title,
  required List<FinanceDocumentRow> rows,
  required String emptyTitle,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FinanceListSheet(
      title: title,
      emptyTitle: emptyTitle,
      children: [
        for (final row in rows)
          _DocumentRow(
            row: row,
            doctype: row.status == 'Receive' || row.status == 'Pay'
                ? 'Payment Entry'
                : '',
          ),
      ],
    ),
  );
}

void _showBankBalances(BuildContext context, List<FinanceBankBalance> rows) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FinanceListSheet(
      title: 'Bank Balance Monitoring',
      emptyTitle: 'Belum ada rekening bank',
      children: [for (final row in rows) _BankBalanceRow(row: row)],
    ),
  );
}

void _showBankBalance(BuildContext context, FinanceBankBalance row) {
  showErpDetailSheet(
    context: context,
    title: row.account,
    subtitle: 'Bank Account',
    statusText: 'Balance',
    rows: [
      ErpDetailRow(label: 'Account', value: row.account),
      ErpDetailRow(
        label: 'Balance',
        value: 'Rp ${formatErpCurrency(row.balance.abs())}',
      ),
    ],
  );
}

class _FinanceListSheet extends StatelessWidget {
  final String title;
  final String emptyTitle;
  final List<Widget> children;

  const _FinanceListSheet({
    required this.title,
    required this.emptyTitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (children.isEmpty)
                ErpEmptyState(title: emptyTitle)
              else
                ...children,
            ],
          ),
        );
      },
    );
  }
}

class _MetricData {
  final String label;
  final double value;
  final IconData icon;
  final bool currency;
  final VoidCallback? onTap;

  const _MetricData(
    this.label,
    this.value,
    this.icon, {
    this.currency = true,
    this.onTap,
  });
}

class _MetricGrid extends StatelessWidget {
  final List<_MetricData> metrics;

  const _MetricGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _MetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _MetricData metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    final value = metric.currency
        ? 'Rp ${formatErpCurrency(metric.value.abs())}'
        : metric.value.toInt().toString();
    return InkWell(
      onTap: metric.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(metric.icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              metric.label,
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
    );
  }
}

class _TrendCard extends StatelessWidget {
  final String title;
  final List<DocumentTrendPoint> points;

  const _TrendCard({required this.title, required this.points});

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<double>(
      0,
      (max, point) => point.value.abs() > max ? point.value.abs() : max,
    );
    return _SectionCard(
      title: title,
      icon: Icons.show_chart_rounded,
      child: SizedBox(
        height: 144,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final point in points)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: maxValue == 0
                                ? 0.04
                                : (point.value.abs() / maxValue).clamp(0.04, 1),
                            child: Container(
                              decoration: BoxDecoration(
                                color: point.value < 0
                                    ? AppColors.warning.withValues(alpha: 0.7)
                                    : AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        point.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.slate,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final List<FinanceReportMetric> rows;

  const _ReportSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      icon: Icons.analytics_rounded,
      child: rows.isEmpty
          ? const ErpEmptyState(
              title: 'Report belum tersedia',
              message: 'Pastikan permission Query Report ERPNext aktif.',
            )
          : Column(
              children: [
                for (final row in rows)
                  _AmountRow(label: row.label, amount: row.value),
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
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

class _AmountRow extends StatelessWidget {
  final String label;
  final double amount;
  final VoidCallback? onTap;

  const _AmountRow({required this.label, required this.amount, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Rp ${formatErpCurrency(amount.abs())}',
              style: TextStyle(
                color: amount < 0 ? AppColors.warning : AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  final FinanceDocumentRow row;
  final String doctype;

  const _DocumentRow({required this.row, this.doctype = ''});

  @override
  Widget build(BuildContext context) {
    return _SimpleRow(
      title: row.title,
      subtitle: '${row.id} • ${row.date}',
      trailing: row.status,
      amount: row.amount,
      onTap: () => _showFinanceDocumentDetail(context, row, doctype: doctype),
    );
  }
}

class _BankBalanceRow extends StatelessWidget {
  final FinanceBankBalance row;

  const _BankBalanceRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return _SimpleRow(
      title: row.account,
      subtitle: 'Bank Account',
      trailing: 'Balance',
      amount: row.balance,
      onTap: () => _showBankBalance(context, row),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final GeneralLedgerRow row;

  const _LedgerRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return _SimpleRow(
      title: row.account,
      subtitle: [
        row.date,
        if (row.party.trim().isNotEmpty) row.party,
      ].join(' • '),
      trailing: row.debit > 0 ? 'Debit' : 'Credit',
      amount: row.debit > 0 ? row.debit : row.credit,
      onTap: () => _showLedgerDetail(context, row),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final double amount;
  final VoidCallback? onTap;

  const _SimpleRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.amount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
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
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  trailing,
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Rp ${formatErpCurrency(amount.abs())}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showFinanceDocumentDetail(
  BuildContext context,
  FinanceDocumentRow row, {
  String doctype = '',
}) {
  showErpDetailSheet(
    context: context,
    title: row.id,
    subtitle: row.title,
    statusText: row.status.isEmpty
        ? (doctype.isEmpty ? 'Document' : doctype)
        : row.status,
    rows: [
      ErpDetailRow(label: 'Document', value: row.id),
      ErpDetailRow(label: 'Title', value: row.title),
      if (doctype.isNotEmpty) ErpDetailRow(label: 'Type', value: doctype),
      if (row.date.isNotEmpty) ErpDetailRow(label: 'Date', value: row.date),
      ErpDetailRow(
        label: 'Amount',
        value: 'Rp ${formatErpCurrency(row.amount.abs())}',
      ),
    ],
  );
}

void _showLedgerDetail(BuildContext context, GeneralLedgerRow row) {
  showErpDetailSheet(
    context: context,
    title: row.account,
    subtitle: row.id,
    statusText: row.debit > 0 ? 'Debit' : 'Credit',
    rows: [
      ErpDetailRow(label: 'GL Entry', value: row.id),
      ErpDetailRow(label: 'Account', value: row.account),
      if (row.party.isNotEmpty) ErpDetailRow(label: 'Party', value: row.party),
      ErpDetailRow(label: 'Date', value: row.date),
      ErpDetailRow(
        label: 'Debit',
        value: 'Rp ${formatErpCurrency(row.debit.abs())}',
      ),
      ErpDetailRow(
        label: 'Credit',
        value: 'Rp ${formatErpCurrency(row.credit.abs())}',
      ),
    ],
  );
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppColors.border),
    boxShadow: [
      BoxShadow(
        color: AppColors.primaryDark.withValues(alpha: 0.045),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
