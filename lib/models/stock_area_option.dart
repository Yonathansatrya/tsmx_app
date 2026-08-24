import 'package:flutter/material.dart';

class StockAreaOption {
  final String areaId;
  final String title;
  final String subtitle;
  final IconData icon;
  final int maxCapacity;

  const StockAreaOption({
    required this.areaId,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inventory_2_outlined,
    this.maxCapacity = 0,
  });
}
