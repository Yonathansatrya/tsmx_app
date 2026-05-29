import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

export '../utils/frappe_status.dart'
    show DeliveryNoteStatusKey, parseDeliveryNoteStatus, normalizeStatusText;

class PurchaseReceipt {
  final String id;
  final String supplier;
  final double value;
  final DeliveryNoteStatusKey statusKey;
  final String statusText;
  final int docStatus;
  final String date;
  final int itemsCount;

  PurchaseReceipt({
    required this.id,
    required this.supplier,
    required this.value,
    required this.statusKey,
    required this.statusText,
    this.docStatus = 0,
    required this.date,
    required this.itemsCount,
  });

  factory PurchaseReceipt.fromJson(Map<String, dynamic> json) {
    final docstatus = NumParse.asInt(json['docstatus']);
    final statusText = normalizeStatusText(
      json['status']?.toString(),
      docstatus: docstatus,
    );

    return PurchaseReceipt(
      id: json['name']?.toString() ?? 'UNKNOWN',
      supplier:
          json['supplier_name']?.toString() ??
          json['supplier']?.toString() ??
          'Unknown Supplier',
      value: NumParse.asDouble(json['grand_total'] ?? json['rounded_total']),
      statusKey: parseDeliveryNoteStatus(statusText, docstatus: docstatus),
      statusText: statusText,
      docStatus: docstatus,
      date: json['posting_date']?.toString() ?? '',
      itemsCount: NumParse.asInt(json['total_qty']),
    );
  }
}
