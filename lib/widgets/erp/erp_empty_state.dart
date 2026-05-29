import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class ErpEmptyState extends StatelessWidget {
  final String title;
  final String message;

  const ErpEmptyState({
    super.key,
    required this.title,
    this.message = 'Pull down to refresh or adjust filters.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: AppColors.slate),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.slate, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
