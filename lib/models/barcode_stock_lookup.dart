import '../utils/num_parse.dart';

class BarcodeStockLookup {
  final String scannedCode;
  final String itemCode;
  final String itemName;
  final String warehouse;
  final double actualQty;
  final double reservedQty;
  final double projectedQty;
  final double valuationRate;

  const BarcodeStockLookup({
    required this.scannedCode,
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.actualQty,
    required this.reservedQty,
    required this.projectedQty,
    required this.valuationRate,
  });

  factory BarcodeStockLookup.fromBin({
    required String scannedCode,
    required String itemCode,
    required String itemName,
    required Map<String, dynamic> bin,
    double valuationRate = 0,
  }) {
    return BarcodeStockLookup(
      scannedCode: scannedCode,
      itemCode: itemCode,
      itemName: itemName,
      warehouse: bin['warehouse']?.toString() ?? '',
      actualQty: NumParse.asDouble(bin['actual_qty']),
      reservedQty: NumParse.asDouble(bin['reserved_qty']),
      projectedQty: NumParse.asDouble(bin['projected_qty']),
      valuationRate: valuationRate,
    );
  }
}
