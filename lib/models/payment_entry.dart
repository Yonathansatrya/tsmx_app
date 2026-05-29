import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

class PaymentEntry {
  final String id;
  final String party;
  final String paymentType;
  final double amount;
  final String statusText;
  final int docStatus;
  final String date;

  PaymentEntry({
    required this.id,
    required this.party,
    required this.paymentType,
    required this.amount,
    required this.statusText,
    this.docStatus = 0,
    required this.date,
  });

  factory PaymentEntry.fromJson(Map<String, dynamic> json) {
    final docstatus = NumParse.asInt(json['docstatus']);
    return PaymentEntry(
      id: json['name']?.toString() ?? 'UNKNOWN',
      party:
          json['party_name']?.toString() ??
          json['party']?.toString() ??
          'Unknown',
      paymentType: json['payment_type']?.toString() ?? '',
      amount: NumParse.asDouble(json['paid_amount'] ?? json['received_amount']),
      statusText: normalizeStatusText(
        json['status']?.toString(),
        docstatus: docstatus,
      ),
      docStatus: docstatus,
      date: json['posting_date']?.toString() ?? '',
    );
  }
}
