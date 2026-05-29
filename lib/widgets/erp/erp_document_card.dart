import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_format.dart';
import 'erp_status_badge.dart';

class ErpDocumentCard extends StatelessWidget {
  final String id;
  final String party;
  final String statusText;
  final String date;
  final double value;
  final String? trailing;
  final VoidCallback? onTap;

  const ErpDocumentCard({
    super.key,
    required this.id,
    required this.party,
    required this.statusText,
    required this.date,
    required this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    id,
                    style: const TextStyle(
                      fontFamily: 'HankenGrotesk',
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                ErpStatusBadge(statusText: statusText),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              party,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.slate,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date.isEmpty ? '—' : date,
                  style: const TextStyle(fontSize: 10, color: AppColors.slate),
                ),
                Text(
                  'Rp ${formatErpCurrency(value)}',
                  style: const TextStyle(
                    fontFamily: 'HankenGrotesk',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            if (trailing != null) ...[
              const SizedBox(height: 6),
              Text(
                trailing!,
                style: const TextStyle(fontSize: 9, color: AppColors.slate),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
