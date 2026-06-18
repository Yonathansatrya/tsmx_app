import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'notification_card.dart';
import 'notification_model.dart';

enum _NotificationFilter { all, unread, warning, info }

class NotificationSheet extends StatefulWidget {
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
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  _NotificationFilter _filter = _NotificationFilter.all;

  String _filterLabel(_NotificationFilter filter) {
    return switch (filter) {
      _NotificationFilter.all => 'Semua',
      _NotificationFilter.unread => 'Baru',
      _NotificationFilter.warning => 'Peringatan',
      _NotificationFilter.info => 'Info',
    };
  }

  List<AppNotification> _filteredNotifications() {
    return widget.notifications.where((item) {
      return switch (_filter) {
        _NotificationFilter.all => true,
        _NotificationFilter.unread => !item.isRead,
        _NotificationFilter.warning => item.type == NotificationType.warning,
        _NotificationFilter.info => item.type == NotificationType.info,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final unread = widget.notifications.where((n) => !n.isRead).length;
    final warnings = widget.notifications
        .where((n) => n.type == NotificationType.warning)
        .length;
    final filtered = _filteredNotifications();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.45,
      maxChildSize: 0.96,
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
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kotak Masuk ERP',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.navy,
                              ),
                            ),
                            Text(
                              '${widget.notifications.length} notifikasi - $unread belum dibaca',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.slate,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _InboxMetric(
                          label: 'Baru',
                          value: unread,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InboxMetric(
                          label: 'Peringatan',
                          value: warnings,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _NotificationFilter.values.map((filter) {
                        final selected = filter == _filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_filterLabel(filter)),
                            selected: selected,
                            showCheckmark: false,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.softGreen,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: selected
                                  ? AppColors.white
                                  : AppColors.primary,
                            ),
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.notifications.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Row(
                  children: [
                    const Text(
                      'Dari ERPNext & aktivitas aplikasi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    if (unread > 0)
                      TextButton.icon(
                        onPressed: widget.onMarkAllRead,
                        icon: const Icon(Icons.done_all_rounded, size: 17),
                        label: const Text(
                          'Tandai dibaca',
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
              child: filtered.isEmpty
                  ? const _EmptyNotifications()
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return NotificationCard(
                          item: item,
                          onTap: () {
                            widget.onNotificationTap?.call(item);
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

class _InboxMetric extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _InboxMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
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
              'Belum ada notifikasi',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.navy,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Approval, perubahan ERPNext, dan pesan dari sistem akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.slate),
            ),
          ],
        ),
      ),
    );
  }
}
