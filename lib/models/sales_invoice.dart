import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

export '../utils/frappe_status.dart'
    show InvoiceStatusKey, parseInvoiceStatus, normalizeStatusText;

class SalesInvoiceItem {
  final String itemCode;
  final String itemName;
  final double qty;
  final double rate;
  final double amount;
  final String warehouse;
  final String uom;

  const SalesInvoiceItem({
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.rate,
    required this.amount,
    this.warehouse = '',
    this.uom = '',
  });

  factory SalesInvoiceItem.fromJson(Map<String, dynamic> json) {
    final itemCode = json['item_code']?.toString() ?? '';
    return SalesInvoiceItem(
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

class SalesInvoice {
  final String id;
  final String customer;
  final double value;
  final double outstandingAmount;
  final InvoiceStatusKey statusKey;
  final String statusText;
  final int docStatus;
  final String date;
  final String dueDate;
  final String tukarFaktur;
  final String tukarFakturDate;
  final String tukarFakturDueDate;
  final List<SalesInvoiceItem> items;

  SalesInvoice({
    required this.id,
    required this.customer,
    required this.value,
    required this.outstandingAmount,
    required this.statusKey,
    required this.statusText,
    this.docStatus = 0,
    required this.date,
    required this.dueDate,
    this.tukarFaktur = '',
    this.tukarFakturDate = '',
    this.tukarFakturDueDate = '',
    this.items = const [],
  });

  factory SalesInvoice.fromJson(Map<String, dynamic> json) {
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
                (e) => SalesInvoiceItem.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
        : <SalesInvoiceItem>[];

    return SalesInvoice(
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
      outstandingAmount: NumParse.asDouble(json['outstanding_amount']),
      statusKey: parseInvoiceStatus(statusText, docstatus: docstatus),
      statusText: statusText,
      docStatus: docstatus,
      date: json['posting_date']?.toString() ?? '',
      dueDate: json['due_date']?.toString() ?? '',
      tukarFaktur: _firstValue(json, const [
        '_resolved_tukar_faktur',
        'tukar_faktur',
        'custom_tukar_faktur',
        'no_tukar_faktur',
        'nomor_tukar_faktur',
        'tukar_faktur_no',
        'tt_no',
        'no_tt',
      ]),
      tukarFakturDate: _firstValue(json, const [
        '_resolved_tukar_faktur_date',
        'tanggal_tukar_faktur',
        'tgl_tukar_faktur',
        'custom_tanggal_tukar_faktur',
        'custom_tgl_tukar_faktur',
        'tukar_faktur_date',
        'tt_date',
        'tanggal_tt',
        'tgl_tt',
      ]),
      tukarFakturDueDate: _firstValue(json, const [
        '_resolved_tukar_faktur_due_date',
        'jatuh_tempo_tukar_faktur',
        'tanggal_jatuh_tempo_tukar_faktur',
        'custom_jatuh_tempo_tukar_faktur',
        'custom_tanggal_jatuh_tempo_tukar_faktur',
        'tukar_faktur_due_date',
        'tt_due_date',
        'jatuh_tempo_tt',
        'tanggal_jatuh_tempo_tt',
        'tgl_jatuh_tempo_tt',
      ]),
      items: items,
    );
  }

  String get collectionDueDate =>
      tukarFakturDueDate.trim().isNotEmpty ? tukarFakturDueDate : dueDate;

  static String _firstValue(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }
}
