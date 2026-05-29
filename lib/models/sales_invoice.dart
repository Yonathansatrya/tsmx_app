import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

export '../utils/frappe_status.dart'
    show InvoiceStatusKey, parseInvoiceStatus, normalizeStatusText;

class SalesInvoice {
  final String id;
  final String customer;
  final double value;
  final double outstandingAmount;
  final InvoiceStatusKey statusKey;
  final String statusText;
  final int docStatus;
  final String date;
  final String dueDate;

  SalesInvoice({
    required this.id,
    required this.customer,
    required this.value,
    required this.outstandingAmount,
    required this.statusKey,
    required this.statusText,
    this.docStatus = 0,
    required this.date,
    required this.dueDate,
  });

  factory SalesInvoice.fromJson(Map<String, dynamic> json) {
    final docstatus = NumParse.asInt(json['docstatus']);
    final statusText = normalizeStatusText(
      json['status']?.toString(),
      docstatus: docstatus,
    );

    return SalesInvoice(
      id: json['name']?.toString() ?? 'UNKNOWN',
      customer:
          json['customer_name']?.toString() ??
          json['customer']?.toString() ??
          'Unknown Customer',
      value: NumParse.asDouble(json['grand_total'] ?? json['rounded_total']),
      outstandingAmount: NumParse.asDouble(json['outstanding_amount']),
      statusKey: parseInvoiceStatus(statusText, docstatus: docstatus),
      statusText: statusText,
      docStatus: docstatus,
      date: json['posting_date']?.toString() ?? '',
      dueDate: json['due_date']?.toString() ?? '',
    );
  }
}
