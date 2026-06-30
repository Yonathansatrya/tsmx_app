import '../models/erp_summary.dart';
import '../utils/num_parse.dart';

class FinanceDashboardData {
  final double cashIn;
  final double cashOut;
  final double dailyCollection;
  final double bankBalance;
  final double? cashFlowTotal;
  final double outstandingAr;
  final double outstandingAp;
  final double expenseTotal;
  final int pendingJournalCount;
  final List<FinanceBankBalance> bankBalances;
  final List<FinanceDocumentRow> journalEntries;
  final List<FinanceDocumentRow> recentJournalEntries;
  final List<FinanceDocumentRow> cashFlowEntries;
  final List<FinanceDocumentRow> arInvoices;
  final List<FinanceDocumentRow> apInvoices;
  final List<FinanceDocumentRow> expenseEntries;
  final List<GeneralLedgerRow> ledgerRows;
  final List<FinanceReportMetric> cashFlowMetrics;
  final List<FinanceReportMetric> profitLoss;
  final List<FinanceReportMetric> balanceSheet;
  final List<DocumentTrendPoint> cashFlowTrend;

  const FinanceDashboardData({
    this.cashIn = 0,
    this.cashOut = 0,
    this.dailyCollection = 0,
    this.bankBalance = 0,
    this.cashFlowTotal,
    this.outstandingAr = 0,
    this.outstandingAp = 0,
    this.expenseTotal = 0,
    this.pendingJournalCount = 0,
    this.bankBalances = const [],
    this.journalEntries = const [],
    this.recentJournalEntries = const [],
    this.cashFlowEntries = const [],
    this.arInvoices = const [],
    this.apInvoices = const [],
    this.expenseEntries = const [],
    this.ledgerRows = const [],
    this.cashFlowMetrics = const [],
    this.profitLoss = const [],
    this.balanceSheet = const [],
    this.cashFlowTrend = const [],
  });

  double get netCashFlow => cashFlowTotal ?? cashIn - cashOut;
}

class FinanceBankBalance {
  final String account;
  final double balance;

  const FinanceBankBalance({required this.account, required this.balance});
}

class FinanceDocumentRow {
  final String id;
  final String title;
  final String date;
  final String status;
  final double amount;

  const FinanceDocumentRow({
    required this.id,
    required this.title,
    required this.date,
    required this.status,
    required this.amount,
  });

  factory FinanceDocumentRow.fromJournalEntry(Map<String, dynamic> json) {
    final id = json['name']?.toString() ?? '';
    return FinanceDocumentRow(
      id: id,
      title: json['title']?.toString().trim().isNotEmpty == true
          ? json['title'].toString()
          : id,
      date: json['posting_date']?.toString() ?? '',
      status: json['workflow_state']?.toString().trim().isNotEmpty == true
          ? json['workflow_state'].toString()
          : json['docstatus']?.toString() == '0'
          ? 'Draft'
          : 'Submitted',
      amount: NumParse.asDouble(json['total_debit']),
    );
  }

  factory FinanceDocumentRow.fromPaymentEntry(Map<String, dynamic> json) {
    final id = json['name']?.toString() ?? '';
    final party = json['party_name']?.toString().trim().isNotEmpty == true
        ? json['party_name'].toString()
        : json['party']?.toString() ?? '';
    final paymentType = json['payment_type']?.toString() ?? '';
    final amount = paymentType == 'Receive'
        ? NumParse.asDouble(
            json['base_received_amount'] ?? json['received_amount'],
          )
        : NumParse.asDouble(json['base_paid_amount'] ?? json['paid_amount']);
    return FinanceDocumentRow(
      id: id,
      title: party.isNotEmpty ? party : id,
      date: json['posting_date']?.toString() ?? '',
      status: paymentType,
      amount: amount,
    );
  }

  factory FinanceDocumentRow.fromInvoice(
    Map<String, dynamic> json, {
    required bool purchase,
  }) {
    final id = json['name']?.toString() ?? '';
    final party = purchase
        ? json['supplier_name']?.toString() ??
              json['supplier']?.toString() ??
              ''
        : json['customer_name']?.toString() ??
              json['customer']?.toString() ??
              '';
    return FinanceDocumentRow(
      id: id,
      title: party.trim().isNotEmpty ? party : id,
      date: json['due_date']?.toString().trim().isNotEmpty == true
          ? json['due_date'].toString()
          : json['posting_date']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      amount: NumParse.asDouble(json['outstanding_amount']),
    );
  }

  factory FinanceDocumentRow.fromExpenseGl(Map<String, dynamic> json) {
    final id = json['voucher_no']?.toString().trim().isNotEmpty == true
        ? json['voucher_no'].toString()
        : json['name']?.toString() ?? '';
    return FinanceDocumentRow(
      id: id,
      title: json['account']?.toString() ?? id,
      date: json['posting_date']?.toString() ?? '',
      status: json['voucher_type']?.toString() ?? 'Expense',
      amount:
          NumParse.asDouble(json['debit']) - NumParse.asDouble(json['credit']),
    );
  }
}

class GeneralLedgerRow {
  final String id;
  final String account;
  final String party;
  final String date;
  final double debit;
  final double credit;

  const GeneralLedgerRow({
    required this.id,
    required this.account,
    required this.party,
    required this.date,
    required this.debit,
    required this.credit,
  });

  factory GeneralLedgerRow.fromJson(Map<String, dynamic> json) {
    return GeneralLedgerRow(
      id: json['name']?.toString() ?? '',
      account: json['account']?.toString() ?? '',
      party: json['party']?.toString() ?? '',
      date: json['posting_date']?.toString() ?? '',
      debit: NumParse.asDouble(json['debit']),
      credit: NumParse.asDouble(json['credit']),
    );
  }
}

class FinanceReportMetric {
  final String label;
  final double value;

  const FinanceReportMetric({required this.label, required this.value});
}
