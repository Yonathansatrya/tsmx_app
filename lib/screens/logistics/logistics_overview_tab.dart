import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'logistics_widgets.dart';

class LogisticsOverviewTab extends StatelessWidget {
  final ValueChanged<int> onMenuSelected;

  const LogisticsOverviewTab({super.key, required this.onMenuSelected});

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {},
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: logisticsPagePadding,
      children: [
        const LogisticsSectionHeader(
          title: 'Dashboard Logistics',
          subtitle: 'Monitoring armada, delivery, dan bukti pengiriman',
          icon: Icons.local_shipping_rounded,
        ),
        logisticsSectionGap,
        Row(
          children: const [
            Expanded(
              child: _LogisticsMetricCard(
                label: 'Mudah',
                value: '5',
                icon: Icons.task_alt_rounded,
                color: AppColors.success,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _LogisticsMetricCard(
                label: 'Sedang/Sulit',
                value: '7',
                icon: Icons.route_rounded,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        logisticsSectionGap,
        const LogisticsSectionHeader(
          title: 'Urutan Eksekusi',
          subtitle: 'Mulai dari form status dan bukti, lalu tracking GPS',
          icon: Icons.view_list_rounded,
        ),
        const SizedBox(height: 12),
        LogisticsActionCard(
          title: 'Tracking Armada',
          subtitle: 'Status loading, berangkat, sampai, bongkar, POD, GPS',
          icon: Icons.route_rounded,
          onTap: () => onMenuSelected(1),
          status: 'Pending',
        ),
        LogisticsActionCard(
          title: 'Delivery Monitoring',
          subtitle: 'Delivery Notes mobile, status pengiriman, bukti customer',
          icon: Icons.assignment_turned_in_rounded,
          onTap: () => onMenuSelected(2),
          status: 'Pending',
        ),
        logisticsSectionGap,
        const LogisticsSectionHeader(
          title: 'Pembagian Tingkat Kesulitan',
          subtitle: 'Supaya pengerjaan cepat tapi tetap aman',
          icon: Icons.account_tree_rounded,
        ),
        const SizedBox(height: 12),
        const _DifficultyBlock(
          title: 'Tahap 1 - Mudah',
          color: AppColors.success,
          items: [
            'Status loading barang',
            'Armada berangkat',
            'Status sampai tujuan',
            'Status bongkar',
            'Delivery Notes Mobile',
            'Status pengiriman',
            'Outstanding delivery monitoring',
          ],
        ),
        const _DifficultyBlock(
          title: 'Tahap 2 - Menengah',
          color: AppColors.warning,
          items: [
            'Foto POD (Proof of Delivery)',
            'Foto bukti pengiriman',
            'Tanda tangan digital customer',
          ],
        ),
        const _DifficultyBlock(
          title: 'Tahap 3 - Sulit',
          color: AppColors.danger,
          items: ['Monitoring perjalanan', 'GPS Tracking driver'],
        ),
      ],
    ),
  );
}

class _LogisticsMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _LogisticsMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: AppColors.cardShadow,
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          foregroundColor: color,
          child: Icon(icon),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: AppColors.slate, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DifficultyBlock extends StatelessWidget {
  final String title;
  final Color color;
  final List<String> items;

  const _DifficultyBlock({
    required this.title,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.18)),
      boxShadow: AppColors.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [LogisticsStatusChip(label: title, color: color)],
        ),
        const SizedBox(height: 10),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
