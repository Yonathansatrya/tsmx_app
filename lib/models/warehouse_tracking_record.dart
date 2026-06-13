class WarehouseBatchRecord {
  final String name;
  final String itemCode;
  final DateTime? manufacturingDate;
  final DateTime? expiryDate;
  final bool disabled;

  const WarehouseBatchRecord({
    required this.name,
    required this.itemCode,
    required this.manufacturingDate,
    required this.expiryDate,
    required this.disabled,
  });

  factory WarehouseBatchRecord.fromJson(Map<String, dynamic> json) =>
      WarehouseBatchRecord(
        name: json['name']?.toString() ?? '',
        itemCode: json['item']?.toString() ?? '',
        manufacturingDate: DateTime.tryParse(
          json['manufacturing_date']?.toString() ?? '',
        ),
        expiryDate: DateTime.tryParse(json['expiry_date']?.toString() ?? ''),
        disabled: json['disabled'] == 1 || json['disabled'] == true,
      );
}

class WarehouseSerialRecord {
  final String name;
  final String itemCode;
  final String warehouse;
  final String status;
  final String batchNo;

  const WarehouseSerialRecord({
    required this.name,
    required this.itemCode,
    required this.warehouse,
    required this.status,
    required this.batchNo,
  });

  factory WarehouseSerialRecord.fromJson(Map<String, dynamic> json) =>
      WarehouseSerialRecord(
        name: json['name']?.toString() ?? '',
        itemCode: json['item_code']?.toString() ?? '',
        warehouse: json['warehouse']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        batchNo: json['batch_no']?.toString() ?? '',
      );
}
