import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

export '../utils/frappe_status.dart'
    show PurchaseOrderStatusKey, parsePurchaseOrderStatus;

class PurchaseOrderItem {
  final String itemCode;
  final String itemName;
  final int qty;
  final double rate;
  final String warehouse;

  PurchaseOrderItem({
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.rate,
    this.warehouse = '',
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    final itemCode = json['item_code']?.toString() ?? '';
    return PurchaseOrderItem(
      itemCode: itemCode,
      itemName:
          json['item_name']?.toString() ??
          (itemCode.isNotEmpty ? itemCode : null) ??
          'Unknown Item',
      qty: NumParse.asInt(json['qty'] ?? json['stock_qty']),
      rate: NumParse.asDouble(json['rate'] ?? json['net_rate']),
      warehouse: json['warehouse']?.toString() ?? '',
    );
  }
}

class PurchaseOrder {
  final String id;
  final String supplierId;
  final String vendor;
  final PurchaseOrderStatusKey statusKey;
  final String statusText;
  final int docStatus;
  final double perReceived;
  final double perBilled;
  final String eta;
  final int itemsCount;
  final double totalValue;
  final List<PurchaseOrderItem> items;

  PurchaseOrder({
    required this.id,
    required this.supplierId,
    required this.vendor,
    required this.statusKey,
    required this.statusText,
    this.docStatus = 0,
    this.perReceived = 0,
    this.perBilled = 0,
    required this.eta,
    required this.itemsCount,
    required this.totalValue,
    this.items = const [],
  });

  bool get isDelayed => statusKey == PurchaseOrderStatusKey.delayed;

  PurchaseOrder copyWith({
    String? id,
    String? supplierId,
    String? vendor,
    PurchaseOrderStatusKey? statusKey,
    String? statusText,
    int? docStatus,
    double? perReceived,
    double? perBilled,
    String? eta,
    int? itemsCount,
    double? totalValue,
    List<PurchaseOrderItem>? items,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      vendor: vendor ?? this.vendor,
      statusKey: statusKey ?? this.statusKey,
      statusText: statusText ?? this.statusText,
      docStatus: docStatus ?? this.docStatus,
      perReceived: perReceived ?? this.perReceived,
      perBilled: perBilled ?? this.perBilled,
      eta: eta ?? this.eta,
      itemsCount: itemsCount ?? this.itemsCount,
      totalValue: totalValue ?? this.totalValue,
      items: items ?? this.items,
    );
  }

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    final id = json['name']?.toString() ?? 'UNKNOWN';

    final vendor =
        json['supplier_name']?.toString() ??
        json['supplier']?.toString() ??
        'Unknown Supplier';
    final supplierId = json['supplier']?.toString() ?? vendor;

    final eta = _formatDate(
      json['schedule_date'] ??
          json['expected_delivery_date'] ??
          json['transaction_date'],
    );

    final itemsCount = NumParse.asInt(json['total_qty']);

    final totalValue = NumParse.asDouble(
      json['rounded_total'] ?? json['grand_total'],
    );

    final docstatus = NumParse.asInt(json['docstatus']);
    final statusText = normalizeStatusText(
      json['status']?.toString(),
      docstatus: docstatus,
    );

    final etaDate = _parseEta(eta);
    final today = DateTime.now();
    final isOverdue =
        etaDate != null &&
        etaDate.isBefore(DateTime(today.year, today.month, today.day));
    final isDelayed =
        isOverdue &&
        !statusText.toLowerCase().contains('completed') &&
        !statusText.toLowerCase().contains('cancel') &&
        !statusText.toLowerCase().contains('closed');

    final statusKey = parsePurchaseOrderStatus(
      statusText,
      docstatus: docstatus,
      isDelayed: isDelayed,
    );

    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .map(
                (e) => PurchaseOrderItem.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
        : <PurchaseOrderItem>[];

    return PurchaseOrder(
      id: id,
      supplierId: supplierId,
      vendor: vendor,
      statusKey: statusKey,
      statusText: statusText,
      docStatus: NumParse.asInt(json['docstatus']),
      perReceived: NumParse.asDouble(json['per_received']),
      perBilled: NumParse.asDouble(json['per_billed']),
      eta: eta,
      itemsCount: itemsCount,
      totalValue: totalValue,
      items: items,
    );
  }

  static String _formatDate(dynamic raw) {
    if (raw == null) return '';
    final text = raw.toString().trim();
    if (text.isEmpty) return '';

    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  static DateTime? _parseEta(String eta) {
    if (eta.isEmpty) return null;

    final iso = DateTime.tryParse(eta);
    if (iso != null) return iso;

    final parts = eta.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }
}
