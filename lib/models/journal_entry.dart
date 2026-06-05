import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

class JournalEntryAccount {
  final String account;
  final String partyType;
  final String party;
  final String costCenter;
  final String remark;
  final double debit;
  final double credit;

  const JournalEntryAccount({
    required this.account,
    this.partyType = '',
    this.party = '',
    this.costCenter = '',
    this.remark = '',
    this.debit = 0,
    this.credit = 0,
  });

  factory JournalEntryAccount.fromJson(Map<String, dynamic> json) {
    return JournalEntryAccount(
      account: json['account']?.toString() ?? '',
      partyType: json['party_type']?.toString() ?? '',
      party: json['party']?.toString() ?? '',
      costCenter: json['cost_center']?.toString() ?? '',
      remark:
          json['user_remark']?.toString() ?? json['remark']?.toString() ?? '',
      debit: NumParse.asDouble(
        json['debit_in_account_currency'] ?? json['debit'],
      ),
      credit: NumParse.asDouble(
        json['credit_in_account_currency'] ?? json['credit'],
      ),
    );
  }
}

class JournalEntry {
  final String id;
  final String voucherType;
  final String company;
  final String postingDate;
  final String statusText;
  final int docStatus;
  final double totalDebit;
  final double totalCredit;
  final double difference;
  final String title;
  final String remark;
  final List<JournalEntryAccount> accounts;

  const JournalEntry({
    required this.id,
    required this.voucherType,
    required this.company,
    required this.postingDate,
    required this.statusText,
    required this.docStatus,
    required this.totalDebit,
    required this.totalCredit,
    required this.difference,
    this.title = '',
    this.remark = '',
    this.accounts = const [],
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final docstatus = NumParse.asInt(json['docstatus']);
    final rawAccounts = json['accounts'];

    return JournalEntry(
      id: json['name']?.toString() ?? 'UNKNOWN',
      voucherType: json['voucher_type']?.toString() ?? 'Journal Entry',
      company: json['company']?.toString() ?? '',
      postingDate:
          json['posting_date']?.toString() ??
          json['creation']?.toString() ??
          '',
      statusText: normalizeStatusText(
        json['status']?.toString() ?? json['workflow_state']?.toString(),
        docstatus: docstatus,
      ),
      docStatus: docstatus,
      totalDebit: NumParse.asDouble(json['total_debit']),
      totalCredit: NumParse.asDouble(json['total_credit']),
      difference: NumParse.asDouble(json['difference']),
      title: json['title']?.toString() ?? '',
      remark:
          json['user_remark']?.toString() ??
          json['remark']?.toString() ??
          json['remarks']?.toString() ??
          '',
      accounts: rawAccounts is List
          ? rawAccounts
                .whereType<Map>()
                .map(
                  (row) => JournalEntryAccount.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList()
          : const [],
    );
  }
}
