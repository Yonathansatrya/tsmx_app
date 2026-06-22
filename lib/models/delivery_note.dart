import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

export '../utils/frappe_status.dart'
    show DeliveryNoteStatusKey, parseDeliveryNoteStatus;

class DeliveryNoteItem {
  final String itemCode;
  final String itemName;
  final double qty;
  final double rate;
  final double amount;
  final String warehouse;
  final String uom;

  DeliveryNoteItem({
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.rate,
    required this.amount,
    this.warehouse = '',
    this.uom = '',
  });

  factory DeliveryNoteItem.fromJson(Map<String, dynamic> json) {
    final itemCode = json['item_code']?.toString() ?? '';
    return DeliveryNoteItem(
      itemCode: itemCode,
      itemName:
          json['item_name']?.toString() ??
          (itemCode.isNotEmpty ? itemCode : null) ??
          'Unknown Item',
      qty: NumParse.asDouble(json['qty'] ?? json['stock_qty']),
      rate: NumParse.asDouble(json['rate'] ?? json['net_rate']),
      amount: NumParse.asDouble(json['amount'] ?? json['net_amount']),
      warehouse: json['warehouse']?.toString() ?? '',
      uom: json['uom']?.toString() ?? json['stock_uom']?.toString() ?? '',
    );
  }
}

class DeliveryNote {
  final String id;
  final String customer;
  final double value;
  final DeliveryNoteStatusKey statusKey;
  final String statusText;
  final int docStatus;
  final String date;
  final int itemsCount;
  final List<DeliveryNoteItem> items;

  DeliveryNote({
    required this.id,
    required this.customer,
    required this.value,
    required this.statusKey,
    required this.statusText,
    this.docStatus = 0,
    required this.date,
    required this.itemsCount,
    this.items = const [],
  });

  factory DeliveryNote.fromJson(Map<String, dynamic> json) {
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
                (e) => DeliveryNoteItem.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
        : <DeliveryNoteItem>[];

    return DeliveryNote(
      id: json['name']?.toString() ?? 'UNKNOWN',
      customer:
          json['customer_name']?.toString() ??
          json['customer']?.toString() ??
          'Unknown Customer',
      value: NumParse.asDouble(
        json['base_net_total'] ??
            json['net_total'] ??
            json['grand_total'] ??
            json['rounded_total'],
      ),
      statusKey: parseDeliveryNoteStatus(statusText, docstatus: docstatus),
      statusText: statusText,
      docStatus: docstatus,
      date:
          json['posting_date']?.toString() ??
          json['transaction_date']?.toString() ??
          '',
      itemsCount: NumParse.asInt(json['total_qty']),
      items: items,
    );
  }

  DeliveryNote copyWith({
    String? id,
    String? customer,
    double? value,
    DeliveryNoteStatusKey? statusKey,
    String? statusText,
    int? docStatus,
    String? date,
    int? itemsCount,
    List<DeliveryNoteItem>? items,
  }) {
    return DeliveryNote(
      id: id ?? this.id,
      customer: customer ?? this.customer,
      value: value ?? this.value,
      statusKey: statusKey ?? this.statusKey,
      statusText: statusText ?? this.statusText,
      docStatus: docStatus ?? this.docStatus,
      date: date ?? this.date,
      itemsCount: itemsCount ?? this.itemsCount,
      items: items ?? this.items,
    );
  }
}
