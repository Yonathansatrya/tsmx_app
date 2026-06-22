import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

export '../utils/frappe_status.dart'
    show DeliveryNoteStatusKey, parseDeliveryNoteStatus, normalizeStatusText;

class PurchaseReceiptItem {
  final String itemCode;
  final String itemName;
  final double qty;
  final double receivedQty;
  final double acceptedQty;
  final double rejectedQty;
  final double rate;
  final double amount;
  final String warehouse;
  final String uom;

  const PurchaseReceiptItem({
    required this.itemCode,
    required this.itemName,
    required this.qty,
    this.receivedQty = 0,
    this.acceptedQty = 0,
    this.rejectedQty = 0,
    required this.rate,
    required this.amount,
    this.warehouse = '',
    this.uom = '',
  });

  double get effectiveReceivedQty => receivedQty > 0 ? receivedQty : qty;
  double get varianceQty => effectiveReceivedQty - qty;

  factory PurchaseReceiptItem.fromJson(Map<String, dynamic> json) {
    final itemCode = json['item_code']?.toString() ?? '';
    return PurchaseReceiptItem(
      itemCode: itemCode,
      itemName:
          json['item_name']?.toString() ??
          (itemCode.isNotEmpty ? itemCode : null) ??
          'Unknown Item',
      qty: NumParse.asDouble(json['qty'] ?? json['stock_qty']),
      receivedQty: NumParse.asDouble(
        json['received_qty'] ?? json['received_stock_qty'],
      ),
      acceptedQty: NumParse.asDouble(
        json['accepted_qty'] ?? json['sample_size'] ?? json['qty'],
      ),
      rejectedQty: NumParse.asDouble(json['rejected_qty']),
      rate: NumParse.asDouble(json['rate'] ?? json['net_rate']),
      amount: NumParse.asDouble(json['amount'] ?? json['net_amount']),
      warehouse:
          json['warehouse']?.toString() ??
          json['accepted_warehouse']?.toString() ??
          '',
      uom: json['uom']?.toString() ?? json['stock_uom']?.toString() ?? '',
    );
  }
}

class PurchaseReceipt {
  final String id;
  final String supplier;
  final double value;
  final DeliveryNoteStatusKey statusKey;
  final String statusText;
  final int docStatus;
  final String date;
  final int itemsCount;
  final List<PurchaseReceiptItem> items;

  PurchaseReceipt({
    required this.id,
    required this.supplier,
    required this.value,
    required this.statusKey,
    required this.statusText,
    this.docStatus = 0,
    required this.date,
    required this.itemsCount,
    this.items = const [],
  });

  double get orderedQty => items.fold<double>(0, (sum, item) => sum + item.qty);
  double get receivedQty =>
      items.fold<double>(0, (sum, item) => sum + item.effectiveReceivedQty);
  double get rejectedQty =>
      items.fold<double>(0, (sum, item) => sum + item.rejectedQty);
  double get varianceQty => receivedQty - orderedQty;

  factory PurchaseReceipt.fromJson(Map<String, dynamic> json) {
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
                (e) =>
                    PurchaseReceiptItem.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
        : <PurchaseReceiptItem>[];

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
      items: items,
    );
  }
}
