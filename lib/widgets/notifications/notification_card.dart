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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: style.color.withValues(alpha: 0.14)),
              color: style.color.withValues(alpha: 0.04),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(style.icon, color: style.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: item.isRead
                                    ? AppColors.slate
                                    : AppColors.navy,
                              ),
                            ),
                          ),
                          if (!item.isRead)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(left: 6),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.slate,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        item.timeString,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.slate.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
          ),
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
