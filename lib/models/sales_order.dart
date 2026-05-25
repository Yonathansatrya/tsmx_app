enum SalesOrderStatus {
  draft,
  pending,
  toReceive,
  toBill,
  toReceiveAndBill,
  delayed,
  completed,
  closed,
  cancelled,
  overdue,
  shipped,
  delivered,
}

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
      qty: int.tryParse(json['qty']?.toString() ?? '0') ?? 0,
      rate: double.tryParse(json['rate']?.toString() ?? '0') ?? 0,
    );
  }
}

class SalesOrder {
  final String id;
  final String customer;
  final double value;
  final SalesOrderStatus status;
  final String date;
  final int itemsCount;
  final List<SalesOrderItem> items;

  SalesOrder({
    required this.id,
    required this.customer,
    required this.value,
    required this.status,
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

    final value =
        double.tryParse(
          json['grand_total']?.toString() ??
              json['net_total']?.toString() ??
              '0',
        ) ??
        0;

    final date =
        json['transaction_date']?.toString() ??
        json['delivery_date']?.toString() ??
        json['creation']?.toString() ??
        '';

    final itemsCount =
        int.tryParse(
          json['total_qty']?.toString() ??
              json['items_count']?.toString() ??
              '0',
        ) ??
        0;

    final statusText = json['status']?.toString() ?? '';
    final statusLower = statusText.toLowerCase();

    SalesOrderStatus status = SalesOrderStatus.pending;

    if (statusLower.contains('draft')) {
      status = SalesOrderStatus.draft;
    } else if (statusLower.contains('overdue')) {
      status = SalesOrderStatus.overdue;
    } else if (statusLower.contains('to bill') ||
        statusLower.contains('tobill')) {
      status = SalesOrderStatus.toBill;
    } else if (statusLower.contains('closed')) {
      status = SalesOrderStatus.closed;
    } else if (statusLower.contains('completed')) {
      status = SalesOrderStatus.completed;
    } else if (statusLower.contains('delivered')) {
      status = SalesOrderStatus.delivered;
    } else if (statusLower.contains('shipped') ||
        statusLower.contains('packed') ||
        statusLower.contains('transit') ||
        statusLower.contains('delivery')) {
      status = SalesOrderStatus.shipped;
    }

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
      status: status,
      date: date,
      itemsCount: itemsCount,
      items: items,
    );
  }

  SalesOrder copyWith({
    String? id,
    String? customer,
    double? value,
    SalesOrderStatus? status,
    String? date,
    int? itemsCount,
    List<SalesOrderItem>? items,
  }) {
    return SalesOrder(
      id: id ?? this.id,
      customer: customer ?? this.customer,
      value: value ?? this.value,
      status: status ?? this.status,
      date: date ?? this.date,
      itemsCount: itemsCount ?? this.itemsCount,
      items: items ?? this.items,
    );
  }
}
