import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import 'notification_card.dart';
import 'notification_model.dart';

enum _NotificationFilter { all, unread, action, warning }

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  _NotificationFilter _filter = _NotificationFilter.all;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final notifications = appState.notifications;
        final unread = notifications.where((item) => !item.isRead).length;
        final filtered = _filteredNotifications(notifications);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _NotificationAppBar(
            title: 'Notifikasi',
            subtitle: unread > 0
                ? '$unread belum dibaca'
                : '${notifications.length} notifikasi',
            loading: appState.isNotificationsLoading,
            onBack: () => Navigator.maybePop(context),
            onRefresh: appState.refreshNotifications,
          ),
          body: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: appState.refreshNotifications,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              children: [
                _NotificationToolbar(
                  selected: _filter,
                  unread: unread,
                  hasNotifications: notifications.isNotEmpty,
                  onSelected: (value) => setState(() => _filter = value),
                  onMarkAllRead: unread > 0
                      ? () => _markAllRead(appState)
                      : null,
                  onClear: notifications.isNotEmpty
                      ? appState.clearNotifications
                      : null,
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.58,
                    child: const _EmptyNotifications(),
                  )
                else
                  ...filtered.map(
                    (item) => NotificationCard(
                      item: item,
                      onTap: () => _openNotificationDetail(
                        context,
                        item,
                        markRead: () => appState.markNotificationRead(item.id),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<AppNotification> _filteredNotifications(
    List<AppNotification> notifications,
  ) {
    return notifications.where((item) {
      return switch (_filter) {
        _NotificationFilter.all => true,
        _NotificationFilter.unread => !item.isRead,
        _NotificationFilter.action => item.type == NotificationType.action,
        _NotificationFilter.warning => item.type == NotificationType.warning,
      };
    }).toList();
  }

  Future<void> _markAllRead(AppState appState) async {
    await appState.markAllNotificationsRead();
    if (!mounted) return;
    setState(() => _filter = _NotificationFilter.all);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua notifikasi ditandai dibaca')),
    );
  }
}

class NotificationSheet extends StatefulWidget {
  final List<AppNotification> notifications;
  final VoidCallback? onMarkAllRead;
  final VoidCallback? onClear;
  final ValueChanged<AppNotification>? onNotificationTap;

  const NotificationSheet({
    super.key,
    required this.notifications,
    this.onMarkAllRead,
    this.onClear,
    this.onNotificationTap,
  });

  static void show(
    BuildContext context, {
    required List<AppNotification> notifications,
    VoidCallback? onMarkAllRead,
    VoidCallback? onClear,
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
          onClear: onClear,
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

  @override
  Widget build(BuildContext context) {
    final unread = widget.notifications.where((item) => !item.isRead).length;
    final filtered = _filteredNotifications();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.46,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _NotificationTitleBlock(
                        title: 'Notifikasi',
                        subtitle: unread > 0
                            ? '$unread belum dibaca'
                            : '${widget.notifications.length} notifikasi',
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: _NotificationToolbar(
                  selected: _filter,
                  unread: unread,
                  hasNotifications: widget.notifications.isNotEmpty,
                  onSelected: (value) => setState(() => _filter = value),
                  onMarkAllRead: unread > 0 ? _markAllRead : null,
                  onClear: widget.notifications.isNotEmpty
                      ? widget.onClear
                      : null,
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const _EmptyNotifications()
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 22),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return NotificationCard(
                            item: item,
                            onTap: () {
                              widget.onNotificationTap?.call(item);
                              _openNotificationDetail(context, item);
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

  List<AppNotification> _filteredNotifications() {
    return widget.notifications.where((item) {
      return switch (_filter) {
        _NotificationFilter.all => true,
        _NotificationFilter.unread => !item.isRead,
        _NotificationFilter.action => item.type == NotificationType.action,
        _NotificationFilter.warning => item.type == NotificationType.warning,
      };
    }).toList();
  }

  void _markAllRead() {
    widget.onMarkAllRead?.call();
    if (!mounted) return;
    setState(() => _filter = _NotificationFilter.all);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua notifikasi ditandai dibaca')),
    );
  }
}

class _NotificationAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;

  const _NotificationAppBar({
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Size get preferredSize => const Size.fromHeight(78);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: preferredSize.height,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: IconButton(
          tooltip: 'Kembali',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
      ),
      titleSpacing: 0,
      title: _NotificationTitleBlock(title: title, subtitle: subtitle),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: loading ? null : onRefresh,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}

class _NotificationTitleBlock extends StatelessWidget {
  final String title;
  final String subtitle;

  const _NotificationTitleBlock({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.slate,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationToolbar extends StatelessWidget {
  final _NotificationFilter selected;
  final int unread;
  final bool hasNotifications;
  final ValueChanged<_NotificationFilter> onSelected;
  final VoidCallback? onMarkAllRead;
  final VoidCallback? onClear;

  const _NotificationToolbar({
    required this.selected,
    required this.unread,
    required this.hasNotifications,
    required this.onSelected,
    required this.onMarkAllRead,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _NotificationFilter.values.map((filter) {
              final isSelected = filter == selected;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_filterLabel(filter, unread)),
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
        ),
        if (hasNotifications) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Aktivitas terbaru',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _ToolbarAction(
                label: 'Read',
                icon: Icons.done_all_rounded,
                onPressed: onMarkAllRead,
              ),
              const SizedBox(width: 6),
              _ToolbarAction(
                label: 'Clear',
                icon: Icons.clear_all_rounded,
                onPressed: onClear,
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _filterLabel(_NotificationFilter filter, int unread) {
    return switch (filter) {
      _NotificationFilter.all => 'Semua',
      _NotificationFilter.unread => unread > 0 ? 'Baru $unread' : 'Baru',
      _NotificationFilter.action => 'Approval',
      _NotificationFilter.warning => 'Peringatan',
    };
  }
}

class _ToolbarAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ToolbarAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: onPressed == null
            ? AppColors.slate
            : AppColors.primary,
        side: BorderSide(
          color: onPressed == null
              ? AppColors.border
              : AppColors.primary.withValues(alpha: 0.22),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}

Future<void> _openNotificationDetail(
  BuildContext context,
  AppNotification item, {
  Future<void> Function()? markRead,
}) async {
  await markRead?.call();
  if (!context.mounted) return;
  final displayItem = markRead == null ? item : item.copyWith(isRead: true);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _NotificationDetailSheet(item: displayItem),
  );
}

class _NotificationDetailSheet extends StatelessWidget {
  final AppNotification item;

  const _NotificationDetailSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final style = notificationStyle(item.type);
    final doc = _documentLabel;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: style.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(style.icon, color: style.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 17,
                              height: 1.22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.timeString.isEmpty
                                ? item.sourceLabel
                                : '${item.sourceLabel} - ${item.timeString}',
                            style: const TextStyle(
                              color: AppColors.slate,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Detail',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (doc.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _DetailRow(label: 'Dokumen', value: doc),
                ],
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Status',
                  value: item.isRead ? 'Dibaca' : 'Baru',
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.slate,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 13,
              fontWeight: FontWeight.w900,
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
              Icons.notifications_none_rounded,
              size: 54,
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
            SizedBox(height: 5),
            Text(
              'Approval dan aktivitas ERPNext akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.slate,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
