import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

class PurchaseInvoice {
  final String id;
  final String supplier;
  final double value;
  final double outstandingAmount;
  final InvoiceStatusKey statusKey;
  final String statusText;
  final int docStatus;
  final String date;
  final String dueDate;

  PurchaseInvoice({
    required this.id,
    required this.supplier,
    required this.value,
    required this.outstandingAmount,
    required this.statusKey,
    required this.statusText,
    this.docStatus = 0,
    required this.date,
    required this.dueDate,
  });

  factory PurchaseInvoice.fromJson(Map<String, dynamic> json) {
    final docstatus = NumParse.asInt(json['docstatus']);
    final statusText = normalizeStatusText(
      json['status']?.toString(),
      docstatus: docstatus,
    );

    return PurchaseInvoice(
      id: json['name']?.toString() ?? 'UNKNOWN',
      supplier:
          json['supplier_name']?.toString() ??
          json['supplier']?.toString() ??
          'Unknown Supplier',
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
