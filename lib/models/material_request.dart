import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

class MaterialRequestItem {
  final String itemCode;
  final String itemName;
  final double qty;
  final String warehouse;
  final String scheduleDate;
  final String uom;

  const MaterialRequestItem({
    required this.itemCode,
    required this.itemName,
    required this.qty,
    this.warehouse = '',
    this.scheduleDate = '',
    this.uom = '',
  });

  factory MaterialRequestItem.fromJson(Map<String, dynamic> json) {
    final itemCode = json['item_code']?.toString() ?? '';
    return MaterialRequestItem(
      itemCode: itemCode,
      itemName:
          json['item_name']?.toString() ??
          (itemCode.isNotEmpty ? itemCode : null) ??
          'Unknown Item',
      qty: NumParse.asDouble(json['qty'] ?? json['stock_qty']),
      warehouse:
          json['warehouse']?.toString() ??
          json['from_warehouse']?.toString() ??
          '',
      scheduleDate: json['schedule_date']?.toString() ?? '',
      uom: json['uom']?.toString() ?? json['stock_uom']?.toString() ?? '',
    );
  }
}

class MaterialRequest {
  final String id;
  final String type;
  final String statusText;
  final InvoiceStatusKey statusKey;
  final int docStatus;
  final String date;
  final String scheduleDate;
  final String company;
  final double estimatedCost;
  final List<MaterialRequestItem> items;

  const MaterialRequest({
    required this.id,
    required this.type,
    required this.statusText,
    required this.statusKey,
    required this.docStatus,
    required this.date,
    required this.scheduleDate,
    required this.company,
    required this.estimatedCost,
    this.items = const [],
  });

  factory MaterialRequest.fromJson(Map<String, dynamic> json) {
    final docstatus = NumParse.asInt(json['docstatus']);
    final statusText = normalizeStatusText(
      json['status']?.toString(),
      docstatus: docstatus,
    );
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (row) => MaterialRequestItem.fromJson(
                  Map<String, dynamic>.from(row),
                ),
              )
              .toList()
        : <MaterialRequestItem>[];

    return MaterialRequest(
      id: json['name']?.toString() ?? 'UNKNOWN',
      type: json['material_request_type']?.toString() ?? 'Purchase',
      statusText: statusText,
      statusKey: parseInvoiceStatus(statusText, docstatus: docstatus),
      docStatus: docstatus,
      date:
          json['transaction_date']?.toString() ??
          json['posting_date']?.toString() ??
          '',
      scheduleDate: json['schedule_date']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      estimatedCost: NumParse.asDouble(json['total_estimated_cost']),
      items: items,
    );
  }
}
