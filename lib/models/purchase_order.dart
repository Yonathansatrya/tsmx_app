enum PurchaseOrderStatus { pendingApproval, inTransit, delayed, completed }

class PurchaseOrder {
  final String id;
  final String vendor;
  final PurchaseOrderStatus status;
  final String eta;
  final int itemsCount;
  final double totalValue;

  PurchaseOrder({
    required this.id,
    required this.vendor,
    required this.status,
    required this.eta,
    required this.itemsCount,
    required this.totalValue,
  });

  PurchaseOrder copyWith({
    String? id,
    String? vendor,
    PurchaseOrderStatus? status,
    String? eta,
    int? itemsCount,
    double? totalValue,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      vendor: vendor ?? this.vendor,
      status: status ?? this.status,
      eta: eta ?? this.eta,
      itemsCount: itemsCount ?? this.itemsCount,
      totalValue: totalValue ?? this.totalValue,
    );
  }

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    final id = json['name']?.toString() ?? json['id']?.toString() ?? 'UNKNOWN';

    final vendor =
        json['supplier_name']?.toString() ??
        json['supplier']?.toString() ??
        json['vendor']?.toString() ??
        'Unknown Vendor';

    final eta =
        json['expected_delivery_date']?.toString() ??
        json['eta']?.toString() ??
        json['delivery_date']?.toString() ??
        '';

    final itemsCount =
        int.tryParse(
          json['total_qty']?.toString() ??
              json['items_count']?.toString() ??
              '0',
        ) ??
        0;

    final totalValue =
        double.tryParse(
          json['rounded_total']?.toString() ??
              json['grand_total']?.toString() ??
              json['total_amount']?.toString() ??
              '0',
        ) ??
        0;

    final statusText = json['status']?.toString() ?? '';
    PurchaseOrderStatus status = PurchaseOrderStatus.pendingApproval;
    final s = statusText.toLowerCase();
    if (s.contains('in transit') ||
        s.contains('transit') ||
        s.contains('in_transit')) {
      status = PurchaseOrderStatus.inTransit;
    } else if (s.contains('delayed') || s.contains('delay')) {
      status = PurchaseOrderStatus.delayed;
    } else if (s.contains('completed') || s.contains('done')) {
      status = PurchaseOrderStatus.completed;
    } else {
      status = PurchaseOrderStatus.pendingApproval;
    }

    return PurchaseOrder(
      id: id,
      vendor: vendor,
      status: status,
      eta: eta,
      itemsCount: itemsCount,
      totalValue: totalValue,
    );
  }
}
