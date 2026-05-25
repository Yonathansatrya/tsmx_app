import '../utils/num_parse.dart';
import '../utils/warehouse_mapper.dart';

enum StockStatus { inStock, lowStock, urgent }

class InventoryItem {
  final String sku;
  final String name;
  final String warehouseId;

  final int quantity;
  final int minStockThreshold;
  final StockStatus status;

  InventoryItem({
    required this.sku,
    required this.name,
    required this.warehouseId,
    required this.quantity,
    required this.minStockThreshold,
    required this.status,
  });

  InventoryItem copyWith({
    String? sku,
    String? name,
    String? warehouseId,
    int? quantity,
    int? minStockThreshold,
    StockStatus? status,
  }) {
    return InventoryItem(
      sku: sku ?? this.sku,
      name: name ?? this.name,
      warehouseId: warehouseId ?? this.warehouseId,
      quantity: quantity ?? this.quantity,
      minStockThreshold: minStockThreshold ?? this.minStockThreshold,
      status: status ?? this.status,
    );
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    final sku = json['item_code']?.toString() ?? json['sku']?.toString() ?? '';
    final name =
        json['item_name']?.toString() ?? json['name']?.toString() ?? sku;

    final warehouseRaw =
        json['warehouse']?.toString() ?? json['warehouse_id']?.toString() ?? '';
    final warehouseId = WarehouseMapper.toAreaId(warehouseRaw);

    final quantity = NumParse.asInt(
      json['actual_qty'] ?? json['quantity'] ?? json['projected_qty'],
    );

    final minThreshold = NumParse.asInt(
      json['min_stock_threshold'],
      fallback: 50,
    );

    StockStatus status;
    if (quantity <= (minThreshold * 0.25)) {
      status = StockStatus.urgent;
    } else if (quantity <= minThreshold) {
      status = StockStatus.lowStock;
    } else {
      status = StockStatus.inStock;
    }

    return InventoryItem(
      sku: sku,
      name: name,
      warehouseId: warehouseId,
      quantity: quantity,
      minStockThreshold: minThreshold,
      status: status,
    );
  }
}
