import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/sales_invoice.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/erp_format.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import 'collection_widgets.dart';

class CustomerPaymentScheduleTab extends StatefulWidget {
  const CustomerPaymentScheduleTab({super.key});

  @override
  State<CustomerPaymentScheduleTab> createState() =>
      _CustomerPaymentScheduleTabState();
}

class _CustomerPaymentScheduleTabState
    extends State<CustomerPaymentScheduleTab> {
  List<SalesInvoice> invoices = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      invoices = await context
          .read<AppState>()
          .fetchCollectionOutstandingInvoices();
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool _isDue(SalesInvoice row) {
    final date = DateTime.tryParse(row.dueDate);
    if (date == null) return false;
    final today = DateTime.now();
    return !date.isAfter(DateTime(today.year, today.month, today.day));
  }

  @override
  Widget build(BuildContext context) {
    final sorted = invoices.toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final due = sorted.where(_isDue).length;
    final total = sorted.fold<double>(
      0,
      (sum, row) => sum + row.outstandingAmount,
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          const CollectionSectionHeader(
            title: 'Janji Bayar Customer',
            subtitle: 'Jadwal bayar mengikuti jatuh tempo invoice ERPNext',
            icon: Icons.event_available_rounded,
          ),
          Row(
            children: [
              Expanded(
                child: CollectionMetricCard(
                  label: 'Total Janji',
                  value: '${sorted.length}',
                  icon: Icons.event_note_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CollectionMetricCard(
                  label: 'Jatuh Tempo',
                  value: '$due',
                  icon: Icons.notification_important_outlined,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CollectionMetricCard(
            label: 'Total Nominal Janji Bayar',
            value: 'Rp ${formatErpCurrency(total)}',
            icon: Icons.payments_outlined,
            color: AppColors.success,
          ),
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            ErpErrorBox(message: error!),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Muat ulang'),
            ),
          ],
          const SizedBox(height: 24),
          const CollectionSectionHeader(
            title: 'Daftar Janji Bayar',
            subtitle: 'Urut dari tanggal jatuh tempo terdekat',
            icon: Icons.list_alt_rounded,
          ),
          if (!loading && error == null && sorted.isEmpty)
            const ErpEmptyState(title: 'Belum ada janji bayar')
          else
            ...sorted.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: _isDue(row)
                          ? AppColors.warning.withValues(alpha: 0.12)
                          : AppColors.softGreen,
                      foregroundColor: _isDue(row)
                          ? AppColors.warning
                          : AppColors.primary,
                      child: Icon(
                        _isDue(row)
                            ? Icons.notification_important_outlined
                            : Icons.event_available_outlined,
                      ),
                    ),
                    title: Text(
                      row.customer,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      'Tanggal janji: ${row.dueDate}\nInvoice: ${row.id}',
                    ),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CollectionStatusChip(
                          label: _isDue(row) ? 'Jatuh Tempo' : 'Terjadwal',
                          color: _isDue(row)
                              ? AppColors.warning
                              : AppColors.primary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rp ${formatErpCurrency(row.outstandingAmount)}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
