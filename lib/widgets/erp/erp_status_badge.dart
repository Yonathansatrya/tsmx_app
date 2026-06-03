import 'package:flutter/material.dart';
import '../../utils/frappe_status.dart';

class ErpStatusBadge extends StatelessWidget {
  final String statusText;

  const ErpStatusBadge({super.key, required this.statusText});

  @override
  Widget build(BuildContext context) {
    final style = styleForStatusText(statusText);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 5),
          Text(
            statusText.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: style.color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
