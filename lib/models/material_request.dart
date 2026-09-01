import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

class MaterialRequestItem {
  final String itemCode;
  final String itemName;
  final double qty;
  final double orderedQty;
  final String uom;
  final String warehouse;
  final String scheduleDate;

  const MaterialRequestItem({
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.orderedQty,
    this.uom = '',
    this.warehouse = '',
    this.scheduleDate = '',
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
      orderedQty: NumParse.asDouble(json['ordered_qty']),
      uom: json['uom']?.toString() ?? json['stock_uom']?.toString() ?? '',
      warehouse:
          json['warehouse']?.toString() ??
          json['from_warehouse']?.toString() ??
          '',
      scheduleDate: json['schedule_date']?.toString() ?? '',
    );
  }
}

class MaterialRequest {
  final String id;
  final String type;
  final String company;
  final String statusText;
  final int docStatus;
  final String transactionDate;
  final String scheduleDate;
  final double totalQty;
  final List<MaterialRequestItem> items;

  const MaterialRequest({
    required this.id,
    required this.type,
    required this.company,
    required this.statusText,
    required this.docStatus,
    required this.transactionDate,
    required this.scheduleDate,
    required this.totalQty,
    this.items = const [],
  });

  int get itemsCount => items.isNotEmpty ? items.length : totalQty.round();

  MaterialRequest copyWith({List<MaterialRequestItem>? items}) {
    return MaterialRequest(
      id: id,
      type: type,
      company: company,
      statusText: statusText,
      docStatus: docStatus,
      transactionDate: transactionDate,
      scheduleDate: scheduleDate,
      totalQty: totalQty,
      items: items ?? this.items,
    );
  }

  factory MaterialRequest.fromJson(Map<String, dynamic> json) {
    final docstatus = NumParse.asInt(json['docstatus']);
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => MaterialRequestItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <MaterialRequestItem>[];

    return MaterialRequest(
      id: json['name']?.toString() ?? 'UNKNOWN',
      type: json['material_request_type']?.toString() ?? 'Purchase',
      company: json['company']?.toString() ?? '',
      statusText: normalizeStatusText(
        json['status']?.toString(),
        docstatus: docstatus,
      ),
      docStatus: docstatus,
      transactionDate: json['transaction_date']?.toString() ?? '',
      scheduleDate: json['schedule_date']?.toString() ?? '',
      totalQty: NumParse.asDouble(json['total_qty']),
      items: items,
    );
  }
}
