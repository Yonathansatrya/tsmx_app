import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/delivery_note.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_format.dart';
import 'logistics_widgets.dart';

class LogisticsOverviewTab extends StatelessWidget {
  final ValueChanged<int> onMenuSelected;

  const LogisticsOverviewTab({super.key, required this.onMenuSelected});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final docs = state.deliveryNotes;
    final outstandingRows = docs.where(_isOutstanding).toList();
    final completed = docs
        .where((doc) => doc.statusKey == DeliveryNoteStatusKey.completed)
        .length;
    final draft = docs.where((doc) => doc.docStatus == 0).length;
    final submitted = docs.where((doc) {
      return doc.docStatus == 1 &&
          doc.statusKey != DeliveryNoteStatusKey.completed &&
          doc.statusKey != DeliveryNoteStatusKey.cancelled &&
          doc.statusKey != DeliveryNoteStatusKey.closed;
    }).length;
    final outstandingValue = outstandingRows.fold<double>(
      0,
      (total, doc) => total + doc.value,
    );

    return RefreshIndicator(
      onRefresh: () => context.read<AppState>().refreshDeliveryNotes(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: logisticsPagePadding,
        children: [
          const LogisticsSectionHeader(
            title: 'Dashboard Logistics',
            subtitle: 'Pantau pengiriman, armada, dan bukti customer',
            icon: Icons.local_shipping_rounded,
          ),
          if (state.isDeliveryNotesLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (state.deliveryNotesError != null) ...[
            const SizedBox(height: 12),
            LogisticsInfoPanel(
              message: state.deliveryNotesError!,
              icon: Icons.error_outline_rounded,
              color: AppColors.danger,
            ),
          ],
          logisticsSectionGap,
          _LogisticsHeroCard(
            outstanding: outstandingRows.length,
            completed: completed,
            value: outstandingValue,
            onTap: () => onMenuSelected(2),
          ),
          logisticsSectionGap,
          Row(
            children: [
              Expanded(
                child: _LogisticsMetricCard(
                  label: 'Submitted',
                  value: '$submitted',
                  icon: Icons.local_shipping_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LogisticsMetricCard(
                  label: 'Draft',
                  value: '$draft',
                  icon: Icons.edit_note_rounded,
                  color: AppColors.slate,
                ),
              ),
            ],
          ),
          logisticsSectionGap,
          const LogisticsSectionHeader(
            title: 'Aksi Cepat',
            subtitle: 'Akses cepat untuk pekerjaan harian logistics',
            icon: Icons.touch_app_rounded,
          ),
          const SizedBox(height: 12),
          LogisticsActionCard(
            title: 'Tracking Armada',
            subtitle:
                '$submitted pengiriman berjalan, $completed sudah selesai',
            icon: Icons.route_rounded,
            onTap: () => onMenuSelected(1),
            status: submitted > 0 ? 'Pantau' : 'Siap',
            color: AppColors.primary,
          ),
          LogisticsActionCard(
            title: 'Delivery Monitoring',
            subtitle:
                '${outstandingRows.length} outstanding, upload POD dan tanda tangan customer',
            icon: Icons.assignment_turned_in_rounded,
            onTap: () => onMenuSelected(2),
            status: outstandingRows.isEmpty ? 'Aman' : 'Cek',
            color: outstandingRows.isEmpty
                ? AppColors.success
                : AppColors.warning,
          ),
          logisticsSectionGap,
          const LogisticsSectionHeader(
            title: 'Ringkasan Kerja',
            subtitle: 'Prioritas yang perlu dicek hari ini',
            icon: Icons.fact_check_outlined,
          ),
          const SizedBox(height: 12),
          _LogisticsWorkSummary(
            outstanding: outstandingRows.length,
            submitted: submitted,
            draft: draft,
            completed: completed,
          ),
        ],
      ),
    );
  }

  static bool _isOutstanding(DeliveryNote doc) {
    return doc.statusKey != DeliveryNoteStatusKey.completed &&
        doc.statusKey != DeliveryNoteStatusKey.cancelled &&
        doc.statusKey != DeliveryNoteStatusKey.closed;
  }
}

class _LogisticsHeroCard extends StatelessWidget {
  final int outstanding;
  final int completed;
  final double value;
  final VoidCallback onTap;

  const _LogisticsHeroCard({
    required this.outstanding,
    required this.completed,
    required this.value,
    required this.onTap,
  });

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
          boxShadow: AppColors.cardShadow,
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
                  child: const Icon(
                    Icons.delivery_dining_rounded,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prioritas Pengiriman',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Pantau outstanding dan bukti customer',
                        style: TextStyle(
                          color: Color(0xFFE3F2EA),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.white),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _HeroMetric(
                    label: 'Outstanding',
                    value: '$outstanding',
                  ),
                ),
                Expanded(
                  child: _HeroMetric(label: 'Completed', value: '$completed'),
                ),
                Expanded(
                  child: _HeroMetric(
                    label: 'Nilai',
                    value: 'Rp ${formatErpCurrency(value)}',
                    compact: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool compact;

  const _HeroMetric({
    required this.label,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.white,
          fontSize: compact ? 12 : 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE3F2EA),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
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

class _LogisticsWorkSummary extends StatelessWidget {
  final int outstanding;
  final int submitted;
  final int draft;
  final int completed;

  const _LogisticsWorkSummary({
    required this.outstanding,
    required this.submitted,
    required this.draft,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
      boxShadow: AppColors.cardShadow,
    ),
    child: Column(
      children: [
        _summaryRow(
          icon: Icons.priority_high_rounded,
          label: 'Outstanding delivery',
          value: '$outstanding',
          color: outstanding > 0 ? AppColors.warning : AppColors.success,
        ),
        const Divider(height: 18),
        _summaryRow(
          icon: Icons.local_shipping_outlined,
          label: 'Pengiriman diproses',
          value: '$submitted',
          color: AppColors.primary,
        ),
        const Divider(height: 18),
        _summaryRow(
          icon: Icons.edit_note_rounded,
          label: 'Draft belum diproses',
          value: '$draft',
          color: AppColors.slate,
        ),
        const Divider(height: 18),
        _summaryRow(
          icon: Icons.task_alt_rounded,
          label: 'Pengiriman selesai',
          value: '$completed',
          color: AppColors.success,
        ),
      ],
    ),
  );

  static Widget _summaryRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) => Row(
    children: [
      CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        child: Icon(icon, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}
