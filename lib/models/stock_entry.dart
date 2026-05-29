import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

class StockEntry {
  final String id;
  final String stockEntryType;
  final String statusText;
  final int docStatus;
  final String date;
  final int itemsCount;

  StockEntry({
    required this.id,
    required this.stockEntryType,
    required this.statusText,
    this.docStatus = 0,
    required this.date,
    required this.itemsCount,
  });

  factory StockEntry.fromJson(Map<String, dynamic> json) {
    final docstatus = NumParse.asInt(json['docstatus']);
    return StockEntry(
      id: json['name']?.toString() ?? 'UNKNOWN',
      stockEntryType: json['stock_entry_type']?.toString() ?? '',
      statusText: normalizeStatusText(
        json['status']?.toString(),
        docstatus: docstatus,
      ),
      docStatus: docstatus,
      date: json['posting_date']?.toString() ?? '',
      itemsCount: NumParse.asInt(json['total_qty']),
    );
  }
}
