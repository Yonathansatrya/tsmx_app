import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import '../../sales/collection/collection_widgets.dart';
import 'create_spg_daily_report_screen.dart';

class SpgDailyReportTab extends StatefulWidget {
  const SpgDailyReportTab({super.key});

  @override
  State<SpgDailyReportTab> createState() => _SpgDailyReportTabState();
}

class _SpgDailyReportTabState extends State<SpgDailyReportTab> {
  List<Map<String, dynamic>> _records = const [];
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
      final records = await context.read<AppState>().fetchSpgDailyReports();
      if (!mounted) return;
      setState(() => _records = records);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateSpgDailyReportScreen()),
    );
    if (created == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
            children: [
              const CollectionSectionHeader(
                title: 'SPG Daily Report',
                subtitle: 'Riwayat stock awal, stock akhir, dan sell out',
                icon: Icons.bar_chart_outlined,
              ),
              if (_loading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                ErpErrorBox(message: _error!),
              ],
              const SizedBox(height: 12),
              if (_records.isEmpty && !_loading)
                const ErpEmptyState(title: 'Belum ada report selling SPG')
              else
                ..._records.map(_recordTile),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'create-spg-daily-report',
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            onPressed: _openCreate,
            icon: const Icon(Icons.add_chart_rounded),
            label: const Text('Selling'),
          ),
        ),
      ],
    );
  }

  Widget _recordTile(Map<String, dynamic> row) {
    final name = row['name']?.toString() ?? '';
    final customer = row['customer_name']?.toString().trim().isNotEmpty == true
        ? row['customer_name'].toString()
        : row['customer']?.toString() ?? '-';
    final date =
        row['report_date']?.toString() ?? row['modified']?.toString() ?? '-';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.softGreen,
          foregroundColor: AppColors.primary,
          child: Icon(Icons.bar_chart_outlined),
        ),
        title: Text(
          customer,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(date, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: name.isEmpty ? null : () => _showDetail(name),
      ),
    );
  }

  Future<void> _showDetail(String name) async {
    try {
      final detail = await context.read<AppState>().fetchSpgDailyReportDetail(
        name,
      );
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _SpgDailyReportDetailSheet(detail: detail),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }
}

class _SpgDailyReportDetailSheet extends StatelessWidget {
  final Map<String, dynamic> detail;

  const _SpgDailyReportDetailSheet({required this.detail});

  @override
  Widget build(BuildContext context) {
    final rows = _childRows(detail['selling_items']);
    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CollectionSectionHeader(
                title:
                    detail['customer_name']?.toString().trim().isNotEmpty ==
                        true
                    ? detail['customer_name'].toString()
                    : detail['customer']?.toString() ?? 'SPG Daily Report',
                subtitle: detail['name']?.toString() ?? '',
                icon: Icons.bar_chart_outlined,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _detailRow(
                        'Employee',
                        detail['employee']?.toString() ?? '',
                      ),
                      _detailRow(
                        'Report Date',
                        detail['report_date']?.toString() ?? '',
                      ),
                      _detailRow('Notes', detail['notes']?.toString() ?? ''),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const ErpEmptyState(title: 'Belum ada item selling')
              else
                ...rows.map(_itemCard),
            ],
          ),
        );
      },
    );
  }

  static List<Map<String, dynamic>> _childRows(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Widget _itemCard(Map<String, dynamic> row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _detailRow('Item', row['item']?.toString() ?? ''),
            _detailRow('Stock Awal', row['stock_awal']?.toString() ?? ''),
            _detailRow('Stock Akhir', row['stock_akhir']?.toString() ?? ''),
            _detailRow('Sell Out', row['sell_out']?.toString() ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.slate,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
