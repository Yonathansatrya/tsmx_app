import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

export '../utils/frappe_status.dart'
    show DeliveryNoteStatusKey, parseDeliveryNoteStatus;

class DeliveryNote {
  final String id;
  final String customer;
  final double value;
  final DeliveryNoteStatusKey statusKey;
  final String statusText;
  final int docStatus;
  final String date;
  final int itemsCount;

  DeliveryNote({
    required this.id,
    required this.customer,
    required this.value,
    required this.statusKey,
    required this.statusText,
    this.docStatus = 0,
    required this.date,
    required this.itemsCount,
  });

  factory DeliveryNote.fromJson(Map<String, dynamic> json) {
    final docstatus = NumParse.asInt(json['docstatus']);
    final statusText = normalizeStatusText(
      json['status']?.toString(),
      docstatus: docstatus,
    );

    return DeliveryNote(
      id: json['name']?.toString() ?? 'UNKNOWN',
      customer:
          json['customer_name']?.toString() ??
          json['customer']?.toString() ??
          'Unknown Customer',
      value: NumParse.asDouble(json['grand_total'] ?? json['rounded_total']),
      statusKey: parseDeliveryNoteStatus(statusText, docstatus: docstatus),
      statusText: statusText,
      docStatus: docstatus,
      date:
          json['posting_date']?.toString() ??
          json['transaction_date']?.toString() ??
          '',
      itemsCount: NumParse.asInt(json['total_qty']),
    );
  }
}
