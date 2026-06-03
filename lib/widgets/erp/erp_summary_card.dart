import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_format.dart';

class ErpSummaryCard extends StatelessWidget {
  final String title;
  final String valueLabel;
  final double totalValue;
  final int documentCount;
  final String? subtitle;
  final bool isLoading;

  const ErpSummaryCard({
    super.key,
    required this.title,
    required this.valueLabel,
    required this.totalValue,
    required this.documentCount,
    this.subtitle,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: AppColors.slate,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else ...[
            Text(
              'Rp ${formatErpCurrency(totalValue)}',
              style: const TextStyle(
                fontFamily: 'HankenGrotesk',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$documentCount $valueLabel',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 10, color: AppColors.slate),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
