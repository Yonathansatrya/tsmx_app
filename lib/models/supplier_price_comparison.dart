import '../utils/num_parse.dart';

class SupplierPriceComparison {
  final String itemCode;
  final String itemName;
  final List<SupplierPriceOption> options;

  const SupplierPriceComparison({
    required this.itemCode,
    required this.itemName,
    required this.options,
  });

  SupplierPriceOption? get cheapest {
    final priced = options.where((option) => option.rate > 0).toList()
      ..sort((a, b) => a.rate.compareTo(b.rate));
    return priced.isEmpty ? null : priced.first;
  }
}

class SupplierPriceOption {
  final String supplier;
  final String supplierName;
  final String source;
  final String reference;
  final String priceList;
  final String currency;
  final double rate;
  final String date;

  const SupplierPriceOption({
    required this.supplier,
    required this.supplierName,
    required this.source,
    required this.reference,
    this.priceList = '',
    this.currency = '',
    required this.rate,
    this.date = '',
  });

  String get displaySupplier {
    if (supplierName.trim().isNotEmpty) return supplierName;
    if (supplier.trim().isNotEmpty) return supplier;
    return priceList.trim().isNotEmpty ? priceList : 'Unknown Supplier';
  }

  factory SupplierPriceOption.fromItemPrice(Map<String, dynamic> json) {
    return SupplierPriceOption(
      supplier: json['supplier']?.toString() ?? '',
      supplierName: json['supplier_name']?.toString() ?? '',
      source: 'Item Price',
      reference: json['name']?.toString() ?? '',
      priceList: json['price_list']?.toString() ?? '',
      currency: json['currency']?.toString() ?? '',
      rate: NumParse.asDouble(json['price_list_rate']),
      date: json['valid_from']?.toString() ?? '',
    );
  }

  factory SupplierPriceOption.fromPurchaseHistory({
    required Map<String, dynamic> row,
    required Map<String, dynamic> parent,
  }) {
    return SupplierPriceOption(
      supplier: parent['supplier']?.toString() ?? '',
      supplierName: parent['supplier_name']?.toString() ?? '',
      source: 'Last PO',
      reference: row['parent']?.toString() ?? '',
      currency: parent['currency']?.toString() ?? '',
      rate: NumParse.asDouble(row['rate'] ?? row['base_rate']),
      date:
          parent['transaction_date']?.toString() ??
          row['schedule_date']?.toString() ??
          '',
    );
  }
}
