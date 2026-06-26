import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import 'notification_card.dart';
import 'notification_model.dart';

enum _NotificationFilter { all, unread, warning, info }

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  _NotificationFilter _filter = _NotificationFilter.all;

  String _filterLabel(_NotificationFilter filter) {
    return switch (filter) {
      _NotificationFilter.all => 'Semua',
      _NotificationFilter.unread => 'Baru',
      _NotificationFilter.warning => 'Peringatan',
      _NotificationFilter.info => 'Info',
    };
  }

  List<AppNotification> _filteredNotifications(
    List<AppNotification> notifications,
  ) {
    return notifications.where((item) {
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
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final notifications = appState.notifications;
        final unread = notifications.where((n) => !n.isRead).length;
        final warnings = notifications
            .where((n) => n.type == NotificationType.warning)
            .length;
        final filtered = _filteredNotifications(notifications);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            toolbarHeight: 64,
            backgroundColor: AppColors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              tooltip: 'Kembali',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text(
              'Notifikasi',
              style: TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: appState.isNotificationsLoading
                    ? null
                    : () => appState.refreshNotifications(),
                icon: const Icon(Icons.sync_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: appState.refreshNotifications,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _NotificationHeaderCard(
                  total: notifications.length,
                  unread: unread,
                  warnings: warnings,
                  loading: appState.isNotificationsLoading,
                ),
                const SizedBox(height: 12),
                _NotificationFilterBar(
                  selected: _filter,
                  labelBuilder: _filterLabel,
                  onSelected: (filter) => setState(() => _filter = filter),
                ),
                if (notifications.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Aktivitas ERPNext',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      if (unread > 0)
                        TextButton.icon(
                          onPressed: appState.markAllNotificationsRead,
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
                ],
                if (filtered.isEmpty)
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.46,
                    child: const _EmptyNotifications(),
                  )
                else
                  ...filtered.map(
                    (item) => NotificationCard(
                      item: item,
                      onTap: () => appState.markNotificationRead(item.id),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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
      backgroundColor: Colors.transparent,
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

class _NotificationHeaderCard extends StatelessWidget {
  final int total;
  final int unread;
  final int warnings;
  final bool loading;

  const _NotificationHeaderCard({
    required this.total,
    required this.unread,
    required this.warnings,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inbox ${context.watch<AppState>().appDisplayName}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$total pesan - $unread belum dibaca',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.slate,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
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
        ],
      ),
    );
  }
}

class _NotificationFilterBar extends StatelessWidget {
  final _NotificationFilter selected;
  final String Function(_NotificationFilter filter) labelBuilder;
  final ValueChanged<_NotificationFilter> onSelected;

  const _NotificationFilterBar({
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _NotificationFilter.values.map((filter) {
          final isSelected = filter == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(labelBuilder(filter)),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.white,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isSelected ? AppColors.white : AppColors.slate,
              ),
              onSelected: (_) => onSelected(filter),
            ),
          );
        }).toList(),
      ),
    );
  }
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
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
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
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.softGreen,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.1),
                            ),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Notifikasi',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.navy,
                                ),
                              ),
                              Text(
                                '${widget.notifications.length} pesan - $unread belum dibaca',
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
                      height: 38,
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
                              backgroundColor: AppColors.white,
                              side: BorderSide(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: selected
                                    ? AppColors.white
                                    : AppColors.slate,
                              ),
                              onSelected: (_) =>
                                  setState(() => _filter = filter),
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
                        'Aktivitas ERPNext',
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
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
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
          ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              label == 'Baru'
                  ? Icons.mark_email_unread_outlined
                  : Icons.warning_amber_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    color: color,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
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
