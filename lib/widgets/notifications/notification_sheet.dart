import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'notification_card.dart';
import 'notification_model.dart';

class NotificationSheet extends StatelessWidget {
  final List<AppNotification> notifications;
  final VoidCallback? onMarkAllRead;
  final ValueChanged<AppNotification>? onNotificationTap;

  const NotificationSheet({
    super.key,
    required this.notifications,
    this.onMarkAllRead,
    this.onNotificationTap,
  });

  static void show(
    BuildContext context, {
    required List<AppNotification> notifications,
    VoidCallback? onMarkAllRead,
    ValueChanged<AppNotification>? onNotificationTap,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return NotificationSheet(
          notifications: notifications,
          onMarkAllRead: onMarkAllRead,
          onNotificationTap: onNotificationTap,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = notifications.where((n) => !n.isRead).length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  Text(
                    unread > 0 ? '$unread unread' : '${notifications.length} items',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (notifications.isNotEmpty && unread > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'From ERPNext',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: onMarkAllRead,
                      child: const Text(
                        'Mark all read',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: notifications.isEmpty
                  ? const _EmptyNotifications()
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        return NotificationCard(
                          item: item,
                          onTap: () {
                            onNotificationTap?.call(item);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 56,
              color: AppColors.slate,
            ),
            SizedBox(height: 12),
            Text(
              'No notifications',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.navy,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Changes in ERPNext (create, update, delete) will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.slate),
            ),
          ],
        ),
      ),
    );
  }
}
