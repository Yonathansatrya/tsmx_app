import '../utils/num_parse.dart';

enum StockMovementDirection { incoming, outgoing }

class StockLedgerMovement {
  final String date;
  final String? time;
  final String warehouse;
  final double qty;
  final double? qtyAfter;
  final String voucherType;
  final String voucherNo;
  final StockMovementDirection direction;

  StockLedgerMovement({
    required this.date,
    this.time,
    required this.warehouse,
    required this.qty,
    this.qtyAfter,
    required this.voucherType,
    required this.voucherNo,
    required this.direction,
  });

  bool get isIncoming => direction == StockMovementDirection.incoming;
  bool get isOutgoing => direction == StockMovementDirection.outgoing;

  double get absQty => qty.abs();

  factory StockLedgerMovement.fromJson(Map<String, dynamic> json) {
    final qty = NumParse.asDouble(json['actual_qty']);
    return StockLedgerMovement(
      date: json['posting_date']?.toString() ?? '',
      time: json['posting_time']?.toString(),
      warehouse: json['warehouse']?.toString() ?? '',
      qty: qty,
      qtyAfter: json.containsKey('qty_after_transaction')
          ? NumParse.asDouble(json['qty_after_transaction'])
          : null,
      voucherType: json['voucher_type']?.toString() ?? '',
      voucherNo: json['voucher_no']?.toString() ?? '',
      direction: qty >= 0
          ? StockMovementDirection.incoming
          : StockMovementDirection.outgoing,
    );
  }
}

class StockLedgerResult {
  final List<StockLedgerMovement> movements;
  final double totalIn;
  final double totalOut;
  final double netQty;

  const StockLedgerResult({
    required this.movements,
    required this.totalIn,
    required this.totalOut,
    required this.netQty,
  });

  factory StockLedgerResult.fromMovements(List<StockLedgerMovement> movements) {
    var totalIn = 0.0;
    var totalOut = 0.0;

    for (final m in movements) {
      if (m.qty > 0) {
        totalIn += m.qty;
      } else if (m.qty < 0) {
        totalOut += m.qty.abs();
      }
    }

    return StockLedgerResult(
      movements: movements,
      totalIn: totalIn,
      totalOut: totalOut,
      netQty: totalIn - totalOut,
    );
  }
}

class StockAgingItem {
  final String itemCode;
  final String itemName;
  final String warehouse;
  final int quantity;
  final double valuationRate;
  final DateTime? lastIncomingDate;
  final int ageDays;

  const StockAgingItem({
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.quantity,
    required this.valuationRate,
    required this.lastIncomingDate,
    required this.ageDays,
  });

  double get stockValue => quantity * valuationRate;
}

class DeadStockItem {
  final String itemCode;
  final String itemName;
  final String warehouse;
  final int quantity;
  final double valuationRate;
  final DateTime? lastMovementDate;
  final int inactiveDays;

  const DeadStockItem({
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.quantity,
    required this.valuationRate,
    required this.lastMovementDate,
    required this.inactiveDays,
  });

  double get stockValue => quantity * valuationRate;
}

class StockMovementVelocityItem {
  final String itemCode;
  final String itemName;
  final String warehouse;
  final int currentQuantity;
  final double outgoingQuantity;
  final int transactionCount;

  const StockMovementVelocityItem({
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.currentQuantity,
    required this.outgoingQuantity,
    required this.transactionCount,
  });
}
