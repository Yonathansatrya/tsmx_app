import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/erp/erp_error_box.dart';

class SpgOverviewTab extends StatefulWidget {
  final ValueChanged<int> onMenuSelected;

  const SpgOverviewTab({super.key, required this.onMenuSelected});

  @override
  State<SpgOverviewTab> createState() => _SpgOverviewTabState();
}

class _SpgOverviewTabState extends State<SpgOverviewTab> {
  int _visitCount = 0;
  int _photoCount = 0;
  int _sellingCount = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = context.read<AppState>();
      final results = await Future.wait([
        state.fetchSpgVisits(),
        state.fetchSpgDailyActivities(),
        state.fetchSpgDailyReports(),
      ]);
      if (!mounted) return;
      setState(() {
        _visitCount = results[0].length;
        _photoCount = results[1].length;
        _sellingCount = results[2].length;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        children: [
          _workspaceHeader(),
          if (_loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErpErrorBox(message: _error!),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.location_on_outlined,
                  value: _visitCount.toString(),
                  label: 'Kunjungan',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  icon: Icons.photo_camera_outlined,
                  value: _photoCount.toString(),
                  label: 'Foto',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  icon: Icons.bar_chart_outlined,
                  value: _sellingCount.toString(),
                  label: 'Selling',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.location_on_outlined,
            title: 'Kunjungan',
            subtitle: 'Check-in dan check-out customer',
            onTap: () => widget.onMenuSelected(1),
          ),
          _ActionTile(
            icon: Icons.photo_camera_outlined,
            title: 'Report Foto',
            subtitle: 'Upload aktivitas display atau kunjungan',
            onTap: () => widget.onMenuSelected(2),
          ),
          _ActionTile(
            icon: Icons.bar_chart_outlined,
            title: 'Report Selling',
            subtitle: 'Isi stock awal, stock akhir, dan sell out',
            onTap: () => widget.onMenuSelected(3),
          ),
        ],
      ),
    );
  }

  Widget _workspaceHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: const [
            CircleAvatar(
              backgroundColor: AppColors.softGreen,
              foregroundColor: AppColors.primary,
              child: Icon(Icons.storefront_outlined),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SPG Workspace',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Pantau kunjungan, foto aktivitas, dan report selling.',
                    style: TextStyle(
                      color: AppColors.slate,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
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
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.softGreen,
          foregroundColor: AppColors.primary,
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.slate,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
