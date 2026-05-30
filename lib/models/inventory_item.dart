import '../utils/num_parse.dart';

enum StockStatus { inStock, lowStock, urgent }

class InventoryItem {
  final String sku;
  final String name;
  final String warehouseId;

  final int quantity;
  final int minStockThreshold;
  final double unitValue;
  final StockStatus status;

  InventoryItem({
    required this.sku,
    required this.name,
    required this.warehouseId,
    required this.quantity,
    required this.minStockThreshold,
    this.unitValue = 0,
    required this.status,
  });

  InventoryItem copyWith({
    String? sku,
    String? name,
    String? warehouseId,
    int? quantity,
    int? minStockThreshold,
    double? unitValue,
    StockStatus? status,
  }) {
    return InventoryItem(
      sku: sku ?? this.sku,
      name: name ?? this.name,
      warehouseId: warehouseId ?? this.warehouseId,
      quantity: quantity ?? this.quantity,
      minStockThreshold: minStockThreshold ?? this.minStockThreshold,
      unitValue: unitValue ?? this.unitValue,
      status: status ?? this.status,
    );
  }

  InventoryItem withRecalculatedStatus() {
    if (minStockThreshold <= 0) {
      return copyWith(
        status: quantity > 0 ? StockStatus.inStock : StockStatus.urgent,
      );
    }

    StockStatus next;
    if (quantity <= (minStockThreshold * 0.25)) {
      next = StockStatus.urgent;
    } else if (quantity <= minStockThreshold) {
      next = StockStatus.lowStock;
    } else {
      next = StockStatus.inStock;
    }
    return copyWith(status: next);
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    final sku = json['item_code']?.toString() ?? json['sku']?.toString() ?? '';
    final name =
        json['item_name']?.toString() ?? json['name']?.toString() ?? sku;

    final warehouseRaw =
        json['warehouse']?.toString() ?? json['warehouse_id']?.toString() ?? '';

    final quantity = NumParse.asInt(
      json['actual_qty'] ?? json['quantity'] ?? json['projected_qty'],
    );

    final minThreshold = NumParse.asInt(
      json['min_stock_threshold'] ?? json['reorder_level'],
      fallback: 0,
    );

    StockStatus status;
    if (minThreshold <= 0) {
      status = quantity > 0 ? StockStatus.inStock : StockStatus.urgent;
    } else if (quantity <= (minThreshold * 0.25)) {
      status = StockStatus.urgent;
    } else if (quantity <= minThreshold) {
      status = StockStatus.lowStock;
    } else {
      status = StockStatus.inStock;
    }

    final unitValue = NumParse.asDouble(
      json['valuation_rate'] ?? json['stock_value'],
    );

    return InventoryItem(
      sku: sku,
      name: name,
      warehouseId: warehouseRaw,
      quantity: quantity,
      minStockThreshold: minThreshold,
      unitValue: unitValue,
      status: status,
    );
  }
}
