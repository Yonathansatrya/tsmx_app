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
    final documentLabel = _documentLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: item.isRead
                    ? AppColors.border
                    : style.color.withValues(alpha: 0.28),
              ),
              boxShadow: item.isRead ? null : AppColors.cardShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: style.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(style.icon, color: style.color, size: 21),
                    ),
                    if (!item.isRead)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: item.isRead
                                    ? AppColors.slate
                                    : AppColors.navy,
                                fontSize: 14,
                                height: 1.2,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.timeString,
                            style: const TextStyle(
                              color: AppColors.slate,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
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
                            color: AppColors.slate,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _StatusPill(
                            label: item.isRead ? 'Dibaca' : 'Baru',
                            color: item.isRead
                                ? AppColors.slate
                                : AppColors.primary,
                          ),
                          if (documentLabel.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                documentLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.slate,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ] else
                            Expanded(
                              child: Text(
                                item.sourceLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.slate,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 11),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.slate,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _documentLabel {
    final type = item.documentType?.trim() ?? '';
    final name = item.documentName?.trim() ?? '';
    if (type.isEmpty && name.isEmpty) return '';
    if (type.isEmpty) return name;
    if (name.isEmpty) return type;
    return '$type - $name';
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
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
        icon: Icons.assignment_turned_in_outlined,
      );
    case NotificationType.warning:
      return const NotificationVisualStyle(
        color: Color(0xFFF59E0B),
        icon: Icons.error_outline_rounded,
      );
    case NotificationType.info:
      return const NotificationVisualStyle(
        color: Color(0xFF2563EB),
        icon: Icons.notifications_none_rounded,
      );
  }
}
