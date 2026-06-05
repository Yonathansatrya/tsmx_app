import 'package:flutter/material.dart';

enum WarehouseType { inbound, ripening, stores }

class StockAreaOption {
  final String areaId;
  final String title;
  final String subtitle;
  final IconData icon;
  final WarehouseType warehouseType;
  final int maxCapacity;

  const StockAreaOption({
    required this.areaId,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inventory_2_outlined,
    this.warehouseType = WarehouseType.stores,
    this.maxCapacity = 900,
  });
}
