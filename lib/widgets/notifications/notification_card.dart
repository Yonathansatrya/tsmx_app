import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'notification_model.dart';

class NotificationCard extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onTap;

  const NotificationCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = notificationStyle(item.type);
    final hasDoc =
        (item.documentType?.isNotEmpty ?? false) ||
        (item.documentName?.isNotEmpty ?? false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: item.isRead
                    ? AppColors.border
                    : style.color.withValues(alpha: 0.22),
              ),
              color: item.isRead
                  ? AppColors.white
                  : style.color.withValues(alpha: 0.045),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: style.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(style.icon, color: style.color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.16,
                                    fontWeight: FontWeight.w900,
                                    color: item.isRead
                                        ? AppColors.slate
                                        : AppColors.navy,
                                  ),
                                ),
                              ),
                              if (!item.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: style.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          if (item.description.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                color: AppColors.slate,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.slate,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (hasDoc)
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (item.documentType?.isNotEmpty ?? false)
                              _MetaChip(
                                label: item.documentType!,
                                color: style.color,
                              ),
                            if (item.documentName?.isNotEmpty ?? false)
                              _MetaChip(
                                label: item.documentName!,
                                color: AppColors.slate,
                              ),
                          ],
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 8),
                    Text(
                      item.timeString,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.slate.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MetaChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class NotificationVisualStyle {
  final Color color;
  final IconData icon;

  const NotificationVisualStyle({required this.color, required this.icon});
}

NotificationVisualStyle notificationStyle(NotificationType type) {
  switch (type) {
    case NotificationType.action:
      return const NotificationVisualStyle(
        color: AppColors.primary,
        icon: Icons.task_alt_rounded,
      );
    case NotificationType.warning:
      return const NotificationVisualStyle(
        color: Color(0xFFF59E0B),
        icon: Icons.warning_amber_rounded,
      );
    case NotificationType.info:
      return const NotificationVisualStyle(
        color: Color(0xFF2563EB),
        icon: Icons.info_outline_rounded,
      );
  }
}
