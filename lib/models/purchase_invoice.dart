import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

class PurchaseInvoiceItem {
  final String itemCode;
  final String itemName;
  final double qty;
  final double rate;
  final double amount;
  final String warehouse;
  final String uom;

  const PurchaseInvoiceItem({
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.rate,
    required this.amount,
    this.warehouse = '',
    this.uom = '',
  });

  factory PurchaseInvoiceItem.fromJson(Map<String, dynamic> json) {
    final itemCode = json['item_code']?.toString() ?? '';
    return PurchaseInvoiceItem(
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
  final List<PurchaseInvoiceItem> items;

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
    this.items = const [],
  });

  factory PurchaseInvoice.fromJson(Map<String, dynamic> json) {
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
                    PurchaseInvoiceItem.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
        : <PurchaseInvoiceItem>[];

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
      items: items,
    );
  }

  DateTime? get parsedDueDate {
    final trimmed = dueDate.trim();
    if (trimmed.isEmpty) return null;
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final parts = trimmed.split('/');
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

  bool get isOutstanding => outstandingAmount > 0;

  int? get daysUntilDue {
    final due = parsedDueDate;
    if (due == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return due.difference(today).inDays;
  }

  bool get isOverdue {
    final days = daysUntilDue;
    return isOutstanding && days != null && days < 0;
  }

  bool get isDueSoon {
    final days = daysUntilDue;
    return isOutstanding && days != null && days >= 0 && days <= 7;
  }
}
