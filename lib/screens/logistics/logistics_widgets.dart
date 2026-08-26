import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/responsive/responsive_layout.dart';

const logisticsPagePadding = EdgeInsets.fromLTRB(16, 14, 16, 88);
EdgeInsets logisticsPagePaddingOf(BuildContext context) {
  return TmsxResponsive.pagePadding(context, top: 14, bottom: 88);
}

const logisticsSectionGap = SizedBox(height: 18);

const logisticsGreen = Color(0xFF16A34A);
const logisticsBlue = Color(0xFF2563EB);
const logisticsCyan = Color(0xFF0891B2);
const logisticsOrange = Color(0xFFF97316);
const logisticsPurple = Color(0xFF7C3AED);

class LogisticsSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  const LogisticsSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.border),
      boxShadow: AppColors.cardShadow,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppColors.primary, size: 23),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.slate,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    ),
  );
}

class LogisticsModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;

  const LogisticsModernCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = AppColors.white,
    this.borderColor = AppColors.border,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: borderColor),
      boxShadow: AppColors.cardShadow,
    ),
    child: child,
  );
}

class LogisticsHeroSummaryCard extends StatelessWidget {
  const LogisticsHeroSummaryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.stats,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<LogisticsHeroStat> stats;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.primary,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.white, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE3F2EA),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.white,
                  ),
              ],
            ),
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  for (final stat in stats)
                    Expanded(child: _LogisticsHeroMetric(stat: stat)),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class LogisticsHeroStat {
  const LogisticsHeroStat({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;
}

class _LogisticsHeroMetric extends StatelessWidget {
  const _LogisticsHeroMetric({required this.stat});

  final LogisticsHeroStat stat;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        stat.value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.white,
          fontSize: stat.compact ? 12 : 19,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        stat.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFE3F2EA),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class LogisticsMetricGrid extends StatelessWidget {
  const LogisticsMetricGrid({super.key, required this.items, this.footer});

  final List<LogisticsMetricItem> items;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var index = 0; index < items.length; index += 2) {
      final first = items[index];
      final second = index + 1 < items.length ? items[index + 1] : null;
      rows.add(
        Row(
          children: [
            Expanded(child: LogisticsMetricCard(item: first)),
            const SizedBox(width: 10),
            Expanded(
              child: second == null
                  ? const SizedBox.shrink()
                  : LogisticsMetricCard(item: second),
            ),
          ],
        ),
      );
      if (index + 2 < items.length) rows.add(const SizedBox(height: 10));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rows,
        if (footer?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            footer!.trim(),
            style: const TextStyle(
              color: AppColors.slate,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class LogisticsMetricItem {
  const LogisticsMetricItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.compactValue = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool compactValue;
}

class LogisticsMetricCard extends StatelessWidget {
  const LogisticsMetricCard({super.key, required this.item});

  final LogisticsMetricItem item;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: AppColors.cardShadow,
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item.icon, color: item.color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: item.compactValue ? 13 : 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.slate,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class LogisticsSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  const LogisticsSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    textInputAction: TextInputAction.search,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hintText,
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: controller.text.trim().isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear',
              onPressed: () {
                controller.clear();
                onChanged?.call('');
              },
              icon: const Icon(Icons.close_rounded),
            ),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    ),
  );
}

class LogisticsActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final String status;
  final Color color;

  const LogisticsActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.status = 'Pending',
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: AppColors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
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
                      subtitle,
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
              const SizedBox(width: 8),
              LogisticsStatusChip(label: status, color: color),
            ],
          ),
        ),
      ),
    ),
  );
}

class LogisticsStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const LogisticsStatusChip({
    super.key,
    required this.label,
    this.color = AppColors.warning,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900),
    ),
  );
}

class LogisticsInfoPanel extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;

  const LogisticsInfoPanel({
    super.key,
    required this.message,
    required this.icon,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: color.withValues(alpha: 0.16)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: AppColors.slate,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}
