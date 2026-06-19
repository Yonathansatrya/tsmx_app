import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/delivery_note.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_format.dart';
import '../../widgets/erp/erp_empty_state.dart';
import 'logistics_widgets.dart';

class LogisticsTrackingTab extends StatelessWidget {
  const LogisticsTrackingTab({super.key});

  Future<void> _refresh(BuildContext context) {
    return context.read<AppState>().refreshDeliveryNotes();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final docs = state.deliveryNotes;
    final outstanding = docs.where(_isOutstanding).length;
    final completed = docs
        .where((doc) => doc.statusKey == DeliveryNoteStatusKey.completed)
        .length;
    final draft = docs.where((doc) => doc.docStatus == 0).length;
    final inProgress = docs.length - completed - draft;

    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: logisticsPagePadding,
        children: [
          const LogisticsSectionHeader(
            title: 'Tracking Armada',
            subtitle: 'Monitoring perjalanan berdasarkan Delivery Note ERPNext',
            icon: Icons.route_rounded,
          ),
          const SizedBox(height: 12),
          const LogisticsInfoPanel(
            message:
                'Tahap ini memakai status bawaan Frappe. GPS tracking dan status granular seperti berangkat/bongkar bisa ditambahkan setelah data armada/driver tersedia.',
            icon: Icons.info_outline_rounded,
          ),
          logisticsSectionGap,
          Row(
            children: [
              Expanded(
                child: _TrackingMetricCard(
                  label: 'Outstanding',
                  value: '$outstanding',
                  icon: Icons.pending_actions_rounded,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrackingMetricCard(
                  label: 'In Progress',
                  value: '$inProgress',
                  icon: Icons.local_shipping_outlined,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TrackingMetricCard(
                  label: 'Completed',
                  value: '$completed',
                  icon: Icons.task_alt_rounded,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrackingMetricCard(
                  label: 'Draft',
                  value: '$draft',
                  icon: Icons.edit_note_rounded,
                  color: AppColors.slate,
                ),
              ),
            ],
          ),
          if (state.isDeliveryNotesLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (state.deliveryNotesError != null) ...[
            const SizedBox(height: 12),
            LogisticsInfoPanel(
              message: _friendlyError(state.deliveryNotesError!),
              icon: Icons.error_outline_rounded,
              color: AppColors.danger,
            ),
          ],
          logisticsSectionGap,
          LogisticsSectionHeader(
            title: 'Monitoring Perjalanan',
            subtitle: '${docs.length} Delivery Note dalam periode aktif',
            icon: Icons.map_outlined,
          ),
          const SizedBox(height: 12),
          if (docs.isEmpty && !state.isDeliveryNotesLoading)
            const ErpEmptyState(
              title: 'Belum ada Delivery Note',
              message: 'Tarik untuk refresh atau cek permission Delivery Note.',
            )
          else
            ...docs.map(_trackingCard),
        ],
      ),
    );
  }

  static bool _isOutstanding(DeliveryNote doc) {
    return doc.statusKey != DeliveryNoteStatusKey.completed &&
        doc.statusKey != DeliveryNoteStatusKey.cancelled &&
        doc.statusKey != DeliveryNoteStatusKey.closed;
  }

  static Widget _trackingCard(DeliveryNote doc) {
    final color = _statusColor(doc);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
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
              child: const Icon(Icons.local_shipping_outlined),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.id,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    doc.customer,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      LogisticsStatusChip(label: doc.statusText, color: color),
                      LogisticsStatusChip(
                        label: doc.date.isEmpty ? 'No Date' : doc.date,
                        color: AppColors.slate,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Rp ${formatErpCurrency(doc.value)}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(DeliveryNote doc) {
    if (doc.statusKey == DeliveryNoteStatusKey.completed) {
      return AppColors.success;
    }
    if (doc.statusKey == DeliveryNoteStatusKey.cancelled ||
        doc.statusKey == DeliveryNoteStatusKey.closed) {
      return AppColors.slate;
    }
    if (doc.docStatus == 0) return AppColors.warning;
    return AppColors.primary;
  }

  static String _friendlyError(Object error) => error
      .toString()
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _TrackingMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TrackingMetricCard({
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
