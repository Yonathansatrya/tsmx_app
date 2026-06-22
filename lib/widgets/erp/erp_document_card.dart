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
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ErpDocumentCard({
    super.key,
    required this.id,
    required this.party,
    required this.statusText,
    required this.date,
    required this.value,
    this.trailing,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final formattedValue = 'Rp ${formatErpCurrency(value)}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'HankenGrotesk',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ErpStatusBadge(statusText: statusText),
                  if (onEdit != null || onDelete != null) ...[
                    const SizedBox(width: 2),
                    PopupMenuButton<String>(
                      tooltip: 'Actions',
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.slate,
                        size: 19,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') onEdit?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                party,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _InfoPill(
                    icon: Icons.calendar_month_outlined,
                    label: date.isEmpty ? '-' : date,
                  ),
                  _InfoPill(
                    icon: Icons.payments_outlined,
                    label: formattedValue,
                    strong: true,
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
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool strong;

  const _InfoPill({
    required this.icon,
    required this.label,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: strong ? AppColors.softGreen : AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: strong ? AppColors.primary : AppColors.slate,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'HankenGrotesk',
                fontSize: strong ? 12 : 10,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                color: strong ? AppColors.primary : AppColors.slate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
