class WarehouseInfo {
  final String name;
  final String displayName;
  final String company;
  final String? parentWarehouse;
  final bool isGroup;
  final bool? isDisabled;

  WarehouseInfo({
    required this.name,
    required this.displayName,
    this.company = '',
    this.parentWarehouse,
    this.isGroup = false,
    this.isDisabled = false,
  });

  factory WarehouseInfo.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    return WarehouseInfo(
      name: name,
      displayName:
          json['warehouse_name']?.toString() ??
          json['name']?.toString() ??
          name,
      company: json['company']?.toString() ?? '',
      parentWarehouse: json['parent_warehouse']?.toString(),
      isGroup: json['is_group'] == 1 || json['is_group'] == true,
      isDisabled: json['disabled'] == 1 || json['disabled'] == true,
    );
  }
}
