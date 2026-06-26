import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/mobile_role_registry.dart';
import '../../models/delivery_note.dart';
import '../../models/inventory_item.dart';
import '../../models/mobile_boot.dart';
import '../../screens/shared/module_screen_registry.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

class DashboardModuleLauncher extends StatelessWidget {
  const DashboardModuleLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final groups = _buildGroups(appState);
    if (groups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _ModuleGroupSection(group: groups[i]),
        ],
      ],
    );
  }

  List<_ModuleGroup> _buildGroups(AppState appState) {
    final enabled = appState.mobileAccess.enabledModules;
    final launchEntries = ModuleScreenRegistry.launchEntriesFor(enabled);
    if (launchEntries.isEmpty) return const [];

    final bootMenus = _bootMenuItems(appState.mobileBoot);
    final grouped = <String, List<_ModuleEntry>>{};

    for (final entry in launchEntries) {
      grouped.putIfAbsent(entry.meta.groupKey, () => []).add(
        _ModuleEntry(
          entry: entry,
          title: MobileRoleRegistry.moduleLabel(
            entry.moduleKey,
            bootMenus: bootMenus,
            fallback: entry.title,
          ),
          subtitle: entry.subtitle,
          badgeLabel: _badgeForEntry(appState, entry),
          badgeColor: _badgeColorForEntry(appState, entry),
        ),
      );
    }

    final groups = <_ModuleGroup>[];
    for (final groupMeta in MobileRoleRegistry.sortedGroups()) {
      final entries = grouped[groupMeta.key];
      if (entries == null || entries.isEmpty) continue;
      groups.add(_ModuleGroup(title: groupMeta.title, entries: entries));
    }

    return groups;
  }

  List<({String module, String label})> _bootMenuItems(MobileBoot? boot) {
    return (boot?.menus ?? const [])
        .map((menu) => (module: menu.module, label: menu.label))
        .toList();
  }

  String _badgeForEntry(AppState appState, ModuleLaunchEntry entry) {
    switch (entry.routeKey) {
      case MobileModule.sales:
        return _countLabel(appState.dashboardSummary.salesOpenCount, 'open');
      case MobileModule.collection:
        return _countLabel(appState.dashboardSummary.unpaidSalesInvoices, 'unpaid');
      case MobileModule.purchase:
        if (appState.purchaseApprovalTodoCount > 0) {
          return '${appState.purchaseApprovalTodoCount} approval';
        }
        return _countLabel(
          appState.dashboardSummary.purchasePendingCount,
          'open',
        );
      case MobileModule.stock:
        final alertCount = appState.dashboardSummary.stockAlerts > 0
            ? appState.dashboardSummary.stockAlerts
            : appState.inventory
                  .where(
                    (item) =>
                        item.status == StockStatus.lowStock ||
                        item.status == StockStatus.urgent,
                  )
                  .length;
        return _countLabel(alertCount, 'alert');
      case MobileModule.warehouse:
        return _countLabel(appState.warehouses.length, 'gudang');
      case MobileModule.logistics:
      case 'logistics.delivery':
        final outstanding = appState.deliveryNotes.where((doc) {
          return doc.statusKey != DeliveryNoteStatusKey.completed &&
              doc.statusKey != DeliveryNoteStatusKey.cancelled &&
              doc.statusKey != DeliveryNoteStatusKey.closed;
        }).length;
        return _countLabel(outstanding, 'jalan');
      default:
        return '';
    }
  }

  Color _badgeColorForEntry(AppState appState, ModuleLaunchEntry entry) {
    if (entry.moduleKey == MobileModule.purchase &&
        appState.purchaseApprovalTodoCount > 0) {
      return AppColors.danger;
    }
    if (entry.moduleKey == MobileModule.stock) return AppColors.warning;
    if (entry.moduleKey == MobileModule.logistics) return AppColors.warning;
    return AppColors.primary;
  }

  String _countLabel(int count, String suffix) {
    if (count <= 0) return '';
    return '$count $suffix';
  }
}

class _ModuleGroup {
  final String title;
  final List<_ModuleEntry> entries;

  const _ModuleGroup({required this.title, required this.entries});
}

class _ModuleEntry {
  final ModuleLaunchEntry entry;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final Color badgeColor;

  const _ModuleEntry({
    required this.entry,
    required this.title,
    required this.subtitle,
    this.badgeLabel = '',
    this.badgeColor = AppColors.primary,
  });
}

class _ModuleGroupSection extends StatelessWidget {
  final _ModuleGroup group;

  const _ModuleGroupSection({required this.group});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pilih modul untuk membuka workspace',
          style: TextStyle(
            color: AppColors.slate.withValues(alpha: 0.9),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ...group.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ModuleEntryTile(entry: entry),
          ),
        ),
      ],
    );
  }
}

class _ModuleEntryTile extends StatelessWidget {
  final _ModuleEntry entry;

  const _ModuleEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => entry.entry.screen),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    entry.entry.meta.icon,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        entry.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.slate,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.badgeLabel.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _ModuleBadge(
                    label: entry.badgeLabel,
                    color: entry.badgeColor,
                  ),
                ],
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.slate,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuleBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ModuleBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 88),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.16)),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900),
    ),
  );
}
