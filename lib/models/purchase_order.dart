enum PurchaseOrderStatus {
  draft,
  pending,
  toReceive,
  toBill,
  toReceiveAndBill,
  delayed,
  completed,
  closed,
  cancelled,
}

class PurchaseOrder {
  final String id;
  final String vendor;
  final PurchaseOrderStatus status;
  final String statusText;
  final String eta;
  final int itemsCount;
  final double totalValue;

  PurchaseOrder({
    required this.id,
    required this.vendor,
    required this.status,
    required this.statusText,
    required this.eta,
    required this.itemsCount,
    required this.totalValue,
  });

  PurchaseOrder copyWith({
    String? id,
    String? vendor,
    PurchaseOrderStatus? status,
    String? statusText,
    String? eta,
    int? itemsCount,
    double? totalValue,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      vendor: vendor ?? this.vendor,
      status: status ?? this.status,
      statusText: statusText ?? this.statusText,
      eta: eta ?? this.eta,
      itemsCount: itemsCount ?? this.itemsCount,
      totalValue: totalValue ?? this.totalValue,
    );
  }

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    final id = json['name']?.toString() ?? 'UNKNOWN';

    final vendor =
        json['supplier_name']?.toString() ??
        json['supplier']?.toString() ??
        'Unknown Supplier';

    final eta = _formatDate(
      json['schedule_date'] ??
          json['expected_delivery_date'] ??
          json['transaction_date'],
    );

    final itemsCount = int.tryParse(json['total_qty']?.toString() ?? '0') ?? 0;

    final totalValue =
        double.tryParse(
          json['rounded_total']?.toString() ??
              json['grand_total']?.toString() ??
              '0',
        ) ??
        0;

    final statusText = json['status']?.toString() ?? 'Unknown';

    final status = _mapStatus(statusText: statusText, eta: eta);

    return PurchaseOrder(
      id: id,
      vendor: vendor,
      status: status,
      statusText: statusText,
      eta: eta,
      itemsCount: itemsCount,
      totalValue: totalValue,
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
    return '$day/${month}/${parsed.year}';
  }

  static PurchaseOrderStatus _mapStatus({
    required String statusText,
    required String eta,
  }) {
    final s = statusText.toLowerCase();

    final etaDate = _parseEta(eta);
    final today = DateTime.now();

    final isOverdue =
        etaDate != null &&
        etaDate.isBefore(DateTime(today.year, today.month, today.day));

    if (s.contains('cancel')) {
      return PurchaseOrderStatus.cancelled;
    }

    if (s.contains('closed')) {
      return PurchaseOrderStatus.closed;
    }

    if (s.contains('completed')) {
      return PurchaseOrderStatus.completed;
    }

    if (isOverdue && !s.contains('completed')) {
      return PurchaseOrderStatus.delayed;
    }

    if (s.contains('to receive and bill')) {
      return PurchaseOrderStatus.toReceiveAndBill;
    }

    if (s.contains('to receive')) {
      return PurchaseOrderStatus.toReceive;
    }

    if (s.contains('to bill')) {
      return PurchaseOrderStatus.toBill;
    }

    if (s.contains('draft')) {
      return PurchaseOrderStatus.draft;
    }

    return PurchaseOrderStatus.pending;
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
