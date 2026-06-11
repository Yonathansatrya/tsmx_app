import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/sales_invoice.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/erp_format.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import 'collection_widgets.dart';

class OutstandingInvoiceTab extends StatefulWidget {
  const OutstandingInvoiceTab({super.key});

  @override
  State<OutstandingInvoiceTab> createState() => _OutstandingInvoiceTabState();
}

class _OutstandingInvoiceTabState extends State<OutstandingInvoiceTab> {
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

  List<_CustomerOutstanding> get summaries {
    final grouped = <String, List<SalesInvoice>>{};
    for (final invoice in invoices) {
      grouped.putIfAbsent(invoice.customer, () => []).add(invoice);
    }
    final result =
        grouped.entries
            .map((entry) => _CustomerOutstanding(entry.key, entry.value))
            .toList()
          ..sort((a, b) => b.total.compareTo(a.total));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final rows = summaries;
    final overdue = rows.where((row) => row.overdueTotal > 0).toList()
      ..sort((a, b) => b.overdueTotal.compareTo(a.overdueTotal));
    final total = rows.fold<double>(0, (sum, row) => sum + row.total);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          const CollectionSectionHeader(
            title: 'Piutang Customer',
            subtitle: 'Lihat customer yang perlu segera ditagih',
            icon: Icons.receipt_long_rounded,
          ),
          Row(
            children: [
              Expanded(
                child: CollectionMetricCard(
                  label: 'Total Piutang',
                  value: 'Rp ${formatErpCurrency(total)}',
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CollectionMetricCard(
                  label: 'Customer Overdue',
                  value: '${overdue.length}',
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                ),
              ),
            ],
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
              label: const Text('Coba lagi'),
            ),
          ],
          const SizedBox(height: 24),
          const CollectionSectionHeader(
            title: 'Prioritas Penagihan',
            subtitle: 'Urut dari nilai overdue terbesar',
            icon: Icons.priority_high_rounded,
          ),
          if (!loading && error == null && overdue.isEmpty)
            const ErpEmptyState(title: 'Tidak ada customer overdue')
          else
            ...overdue.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFF7ED),
                      foregroundColor: AppColors.warning,
                      child: Icon(Icons.notifications_active_outlined),
                    ),
                    title: Text(
                      row.customer,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          CollectionStatusChip(
                            label: '${row.overdueCount} invoice',
                            color: AppColors.warning,
                          ),
                          CollectionStatusChip(
                            label: 'Tertua ${row.oldestOverdueDays} hari',
                            color: AppColors.danger,
                          ),
                        ],
                      ),
                    ),
                    trailing: Text(
                      'Rp ${formatErpCurrency(row.overdueTotal)}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          const CollectionSectionHeader(
            title: 'Semua Piutang',
            subtitle: 'Tekan customer untuk melihat rincian invoice',
            icon: Icons.people_alt_rounded,
          ),
          if (!loading && error == null && rows.isEmpty)
            const ErpEmptyState(title: 'Tidak ada outstanding piutang')
          else
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ExpansionTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.softGreen,
                      foregroundColor: AppColors.primary,
                      child: Icon(Icons.storefront_outlined),
                    ),
                    title: Text(
                      row.customer,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${row.invoices.length} invoice outstanding',
                    ),
                    trailing: Text(
                      'Rp ${formatErpCurrency(row.total)}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    children: row.invoices
                        .map(
                          (invoice) => ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.description_outlined,
                              size: 20,
                            ),
                            title: Text(
                              invoice.id,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text('Jatuh tempo ${invoice.dueDate}'),
                            trailing: Text(
                              'Rp ${formatErpCurrency(invoice.outstandingAmount)}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CustomerOutstanding {
  final String customer;
  final List<SalesInvoice> invoices;

  const _CustomerOutstanding(this.customer, this.invoices);

  double get total =>
      invoices.fold(0, (sum, invoice) => sum + invoice.outstandingAmount);

  Iterable<SalesInvoice> get overdueInvoices {
    final today = DateTime.now();
    return invoices.where((invoice) {
      final due = DateTime.tryParse(invoice.dueDate);
      return due != null &&
          due.isBefore(DateTime(today.year, today.month, today.day));
    });
  }

  int get overdueCount => overdueInvoices.length;

  double get overdueTotal => overdueInvoices.fold(
    0,
    (sum, invoice) => sum + invoice.outstandingAmount,
  );

  int get oldestOverdueDays {
    final today = DateTime.now();
    var oldest = 0;
    for (final invoice in overdueInvoices) {
      final due = DateTime.tryParse(invoice.dueDate);
      if (due == null) continue;
      final days = today.difference(due).inDays;
      if (days > oldest) oldest = days;
    }
    return oldest;
  }
}
