part of '../finance_main_screen.dart';

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
  final _FinanceAccess access;

  const _FinanceWorkspaceTab({required this.initialView, required this.access});

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

    final access = widget.access;
    final paymentRows = access.canReadPaymentEntry
        ? await _safeFetchResource(
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
          )
        : const <Map<String, dynamic>>[];

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

    final arRows = access.canReadSalesInvoice
        ? await _safeFetchResource(
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
          )
        : const <Map<String, dynamic>>[];
    final apRows = access.canReadPurchaseInvoice
        ? await _safeFetchResource(
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
          )
        : const <Map<String, dynamic>>[];
    final outstandingAr = arRows.fold<double>(
      0,
      (sum, row) => sum + NumParse.asDouble(row['outstanding_amount']),
    );
    final outstandingAp = apRows.fold<double>(
      0,
      (sum, row) => sum + NumParse.asDouble(row['outstanding_amount']),
    );

    final accountRows = access.canReadAccount
        ? await _safeFetchResource(
            state,
            'Account',
            fields: const ['name', 'account_name', 'account_type', 'root_type'],
            filters: [
              ['is_group', '=', 0],
              ...companyFilter,
            ],
            limit: 10000,
          )
        : const <Map<String, dynamic>>[];
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

    final bankBalances = access.canReadGlEntry
        ? await _accountBalances(
            state,
            accounts: bankAccounts,
            to: to,
            company: company,
          )
        : const <FinanceBankBalance>[];
    final bankBalance = bankBalances.fold<double>(
      0,
      (sum, row) => sum + row.balance,
    );
    final collectionLedgerRows = access.canReadGlEntry
        ? await _collectionLedgerEntries(
            state,
            bankAccounts: bankAccounts,
            from: from,
            to: to,
            company: company,
          )
        : const <Map<String, dynamic>>[];
    final ledgerCollectionTotal = collectionLedgerRows.fold<double>(
      0,
      (sum, row) => sum + NumParse.asDouble(row['debit']),
    );
    final collectionEntries = [
      ...paymentRows
          .where(
            (row) =>
                row['payment_type']?.toString() == 'Receive' &&
                row['party_type']?.toString() == 'Customer',
          )
          .map(FinanceDocumentRow.fromPaymentEntry),
      if (dailyCollection == 0)
        ...collectionLedgerRows.map(FinanceDocumentRow.fromCollectionGl),
    ];
    if (dailyCollection == 0) {
      dailyCollection = ledgerCollectionTotal;
    }

    final glExpenseTotal = access.canReadGlEntry
        ? await _expenseTotal(
            state,
            accounts: expenseAccounts,
            from: from,
            to: to,
            company: company,
          )
        : 0.0;
    final expenseEntries = access.canReadGlEntry
        ? await _expenseEntries(
            state,
            accounts: expenseAccounts,
            from: from,
            to: to,
            company: company,
          )
        : const <Map<String, dynamic>>[];

    final approvalCandidateRows = access.canReadJournalEntry
        ? await _safeFetchResource(
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
              ['docstatus', '<', 2],
              ...companyFilter,
            ],
            orderBy: 'modified desc',
            limit: 100,
          )
        : const <Map<String, dynamic>>[];
    final journalRows = approvalCandidateRows.where(_isJournalPending).toList();
    final recentJournalRows = access.canReadJournalEntry
        ? await _safeFetchResource(
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
              ['posting_date', '>=', fromText],
              ['posting_date', '<=', toText],
              ...companyFilter,
            ],
            orderBy: 'posting_date desc, modified desc',
            limit: 30,
          )
        : const <Map<String, dynamic>>[];

    final ledgerRows = access.canReadGlEntry
        ? await _safeFetchResource(
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
          )
        : const <Map<String, dynamic>>[];

    final cashFlowMetrics = access.canReadGlEntry
        ? await _loadCashFlowMetrics(
            state,
            from: from,
            to: to,
            company: company,
          )
        : const <FinanceReportMetric>[];
    final cashFlowReportTotal = _metricValue(
      cashFlowMetrics,
      'Net Change in Cash',
    );
    final cashFlowReportTrend = cashFlowMetrics.isEmpty
        ? trend
        : [
            for (final metric in cashFlowMetrics)
              DocumentTrendPoint(
                label: _shortCashFlowLabel(metric.label),
                value: metric.value,
              ),
          ];

    final profitLoss = access.canReadGlEntry
        ? await _loadReportMetrics(
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
          )
        : const <FinanceReportMetric>[];
    final expenseTotal =
        _metricValue(profitLoss, 'Total Expense') ?? glExpenseTotal;
    final balanceSheet = access.canReadGlEntry
        ? await _loadReportMetrics(
            state,
            reportName: 'Balance Sheet',
            from: from,
            to: to,
            company: company,
            labels: const ['Total Asset', 'Total Liability', 'Total Equity'],
          )
        : const <FinanceReportMetric>[];

    return FinanceDashboardData(
      cashIn: cashIn,
      cashOut: cashOut,
      cashFlowTotal: cashFlowReportTotal,
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
      recentJournalEntries: recentJournalRows
          .map(FinanceDocumentRow.fromJournalEntry)
          .toList(),
      cashFlowEntries: paymentRows
          .map(FinanceDocumentRow.fromPaymentEntry)
          .toList(),
      collectionEntries: collectionEntries,
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
      cashFlowMetrics: cashFlowMetrics,
      profitLoss: profitLoss,
      balanceSheet: balanceSheet,
      cashFlowTrend: cashFlowReportTrend,
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
    if (reportBalances.any((row) => row.balance != 0)) return reportBalances;

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

  Future<List<Map<String, dynamic>>> _collectionLedgerEntries(
    AppState state, {
    required List<String> bankAccounts,
    required DateTime from,
    required DateTime to,
    required String company,
  }) async {
    if (bankAccounts.isEmpty) return const [];
    return _safeFetchResource(
      state,
      'GL Entry',
      fields: const [
        'name',
        'posting_date',
        'account',
        'party_type',
        'party',
        'voucher_type',
        'voucher_no',
        'debit',
      ],
      filters: [
        ['is_cancelled', '=', 0],
        ['posting_date', '>=', DateRangePresets.toFrappeDate(from)],
        ['posting_date', '<=', DateRangePresets.toFrappeDate(to)],
        ['debit', '>', 0],
        ['party_type', '=', 'Customer'],
        if (company.trim().isNotEmpty) ['company', '=', company.trim()],
        ['account', 'in', bankAccounts],
      ],
      orderBy: 'posting_date desc, creation desc',
      limit: 100,
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

  Future<List<FinanceReportMetric>> _loadCashFlowMetrics(
    AppState state, {
    required DateTime from,
    required DateTime to,
    required String company,
  }) async {
    try {
      final response = await state.frappeService.callMethod(
        'frappe.desk.query_report.run',
        args: {
          'report_name': 'Cash Flow',
          'filters': {
            if (company.trim().isNotEmpty) 'company': company.trim(),
            'filter_based_on': 'Fiscal Year',
            'from_fiscal_year': from.year.toString(),
            'to_fiscal_year': to.year.toString(),
            'periodicity': 'Yearly',
            'include_default_book_entries': 1,
            'show_opening_and_closing_balance': 0,
          },
          'ignore_prepared_report': true,
          'are_default_filters': false,
        },
      );
      final report = _queryReportPayload(response);
      final columns = _queryReportColumns(report?['columns']);
      final rows = _queryReportRows(report?['result'] ?? report?['data']);
      final labels = const [
        'Net Cash from Operations',
        'Net Cash from Investing',
        'Net Cash from Financing',
        'Net Change in Cash',
      ];
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

  double? _metricValue(List<FinanceReportMetric> rows, String label) {
    for (final row in rows) {
      if (row.label.toLowerCase() == label.toLowerCase()) return row.value;
    }
    return null;
  }

  String _shortCashFlowLabel(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('operations')) return 'Operasi';
    if (normalized.contains('investing')) return 'Investasi';
    if (normalized.contains('financing')) return 'Pendanaan';
    if (normalized.contains('net change')) return 'Net Cash';
    return label;
  }

  bool _isJournalPending(Map<String, dynamic> row) {
    if (row['docstatus']?.toString() == '0') return true;
    final workflowState = row['workflow_state']?.toString().toLowerCase() ?? '';
    if (workflowState.isEmpty) return false;
    const pendingWords = ['pending', 'approval', 'review', 'check'];
    return pendingWords.any(workflowState.contains);
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
        padding: TmsxResponsive.pagePadding(context, top: 18, bottom: 96),
        children: [
          _FinancePeriodCard(
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
