import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

export '../utils/frappe_status.dart'
    show SalesOrderStatusKey, parseSalesOrderStatus;

class SalesOrderItem {
  final String itemName;
  final int qty;
  final double rate;

  SalesOrderItem({
    required this.itemName,
    required this.qty,
    required this.rate,
  });

  factory SalesOrderItem.fromJson(Map<String, dynamic> json) {
    return SalesOrderItem(
      itemName:
          json['item_name']?.toString() ??
          json['item_code']?.toString() ??
          'Unknown Item',
      qty: NumParse.asInt(json['qty'] ?? json['stock_qty']),
      rate: NumParse.asDouble(json['rate'] ?? json['net_rate']),
    );
  }
}

class SalesOrder {
  final String id;
  final String customer;
  final double value;
  final SalesOrderStatusKey statusKey;
  final String statusText;
  final int docStatus;
  final double perDelivered;
  final double perBilled;
  final String date;
  final int itemsCount;
  final List<SalesOrderItem> items;

  SalesOrder({
    required this.id,
    required this.customer,
    required this.value,
    required this.statusKey,
    required this.statusText,
    this.docStatus = 0,
    this.perDelivered = 0,
    this.perBilled = 0,
    required this.date,
    required this.itemsCount,
    this.items = const [],
  });

  factory SalesOrder.fromJson(Map<String, dynamic> json) {
    final id = json['name']?.toString() ?? json['id']?.toString() ?? 'UNKNOWN';

    final customer =
        json['customer_name']?.toString() ??
        json['customer']?.toString() ??
        'Unknown Customer';

    final value = NumParse.asDouble(
      json['grand_total'] ?? json['rounded_total'] ?? json['net_total'],
    );

    final date =
        json['transaction_date']?.toString() ??
        json['delivery_date']?.toString() ??
        json['creation']?.toString() ??
        '';

    final itemsCount = NumParse.asInt(json['total_qty'] ?? json['items_count']);

    final docstatus = NumParse.asInt(json['docstatus']);
    final statusText = normalizeStatusText(
      json['status']?.toString(),
      docstatus: docstatus,
    );
    final statusKey = parseSalesOrderStatus(statusText, docstatus: docstatus);

    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .map((e) => SalesOrderItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <SalesOrderItem>[];

    return SalesOrder(
      id: id,
      customer: customer,
      value: value,
      statusKey: statusKey,
      statusText: statusText,
      docStatus: NumParse.asInt(json['docstatus']),
      perDelivered: NumParse.asDouble(json['per_delivered']),
      perBilled: NumParse.asDouble(json['per_billed']),
      date: date,
      itemsCount: itemsCount,
      items: items,
    );
  }

  SalesOrder copyWith({
    String? id,
    String? customer,
    double? value,
    SalesOrderStatusKey? statusKey,
    String? statusText,
    String? date,
    int? itemsCount,
    List<SalesOrderItem>? items,
  }) {
    return SalesOrder(
      id: id ?? this.id,
      customer: customer ?? this.customer,
      value: value ?? this.value,
      statusKey: statusKey ?? this.statusKey,
      statusText: statusText ?? this.statusText,
      date: date ?? this.date,
      itemsCount: itemsCount ?? this.itemsCount,
      items: items ?? this.items,
    );
  }
}
