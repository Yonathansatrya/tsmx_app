class WarehouseInfo {
  final String name;
  final String displayName;
  final String? parentWarehouse;
  final bool isGroup;

  WarehouseInfo({
    required this.name,
    required this.displayName,
    this.parentWarehouse,
    this.isGroup = false,
  });

  factory WarehouseInfo.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    return WarehouseInfo(
      name: name,
      displayName:
          json['warehouse_name']?.toString() ??
          json['name']?.toString() ??
          name,
      parentWarehouse: json['parent_warehouse']?.toString(),
      isGroup: json['is_group'] == 1 || json['is_group'] == true,
    );
  }
}
