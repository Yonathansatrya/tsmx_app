import 'package:flutter/material.dart';

import '../../models/inventory_item.dart';
import '../../theme/app_colors.dart';

class DashboardStockAlertRow extends StatelessWidget {
  final InventoryItem item;

  const DashboardStockAlertRow({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final alertColor = item.status == StockStatus.urgent
        ? Colors.red.shade400
        : Colors.orange.shade700;

    final label = item.status == StockStatus.urgent ? 'URGENT' : 'LOW';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF7F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StockInfo(item: item),
          ),
          _StockBadge(
            label: label,
            color: alertColor,
          ),
        ],
      ),
    );
  }
}

class _StockInfo extends StatelessWidget {
  final InventoryItem item;

  const _StockInfo({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${item.warehouseId} • ${item.quantity} units',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.slate,
          ),
        ),
      ],
    );
  }
}

class _StockBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StockBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}