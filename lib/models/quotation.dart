import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

class Quotation {
  final String id;
  final String customer;
  final double value;
  final String statusText;
  final int docStatus;
  final String date;

  Quotation({
    required this.id,
    required this.customer,
    required this.value,
    required this.statusText,
    this.docStatus = 0,
    required this.date,
  });

  factory Quotation.fromJson(Map<String, dynamic> json) {
    final docstatus = NumParse.asInt(json['docstatus']);
    return Quotation(
      id: json['name']?.toString() ?? 'UNKNOWN',
      customer:
          json['customer_name']?.toString() ??
          json['party_name']?.toString() ??
          json['customer']?.toString() ??
          'Unknown',
      value: NumParse.asDouble(json['grand_total'] ?? json['rounded_total']),
      statusText: normalizeStatusText(
        json['status']?.toString(),
        docstatus: docstatus,
      ),
      docStatus: docstatus,
      date: json['transaction_date']?.toString() ?? '',
    );
  }
}
