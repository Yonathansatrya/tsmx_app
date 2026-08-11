import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/sales_invoice.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/date_range_presets.dart';
import '../../../utils/erp_format.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import 'ar_aging_tab.dart';
import 'collection_widgets.dart';

class OutstandingInvoiceTab extends StatefulWidget {
  const OutstandingInvoiceTab({
    super.key,
    required this.range,
    required this.dateBasis,
    required this.applyDateFilter,
  });

  final DateRangePreset range;
  final CollectionAgingDateBasis dateBasis;
  final bool applyDateFilter;

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
    for (final invoice in filteredInvoices) {
      grouped.putIfAbsent(invoice.customer, () => []).add(invoice);
    }
    final result =
        grouped.entries
            .map((entry) => _CustomerOutstanding(entry.key, entry.value))
            .toList()
          ..sort((a, b) => b.total.compareTo(a.total));
    return result;
  }

  List<SalesInvoice> get filteredInvoices {
    if (!widget.applyDateFilter) return invoices;
    return invoices.where((invoice) {
      final rawDate = widget.dateBasis == CollectionAgingDateBasis.invoiceDate
          ? invoice.date
          : invoice.tukarFakturDate;
      final parsed = DateTime.tryParse(rawDate);
      if (parsed == null) return false;
      final date = DateTime(parsed.year, parsed.month, parsed.day);
      final from = DateTime(
        widget.range.from.year,
        widget.range.from.month,
        widget.range.from.day,
      );
      final to = DateTime(
        widget.range.to.year,
        widget.range.to.month,
        widget.range.to.day,
      );
      return !date.isBefore(from) && !date.isAfter(to);
    }).toList();
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
                child: _PriorityCollectionCard(row: row),
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
                child: _CustomerOutstandingCard(row: row),
              ),
            ),
        ],
      ),
    );
  }
}

class _PriorityCollectionCard extends StatelessWidget {
  const _PriorityCollectionCard({required this.row});

  final _CustomerOutstanding row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.warning,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.customer,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
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
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Rp ${formatErpCurrency(row.overdueTotal)}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerOutstandingCard extends StatelessWidget {
  const _CustomerOutstandingCard({required this.row});

  final _CustomerOutstanding row;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 14),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          title: Text(
            row.customer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${row.invoices.length} invoice outstanding',
              style: const TextStyle(
                color: AppColors.slate,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          trailing: Text(
            'Rp ${formatErpCurrency(row.total)}',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          children: row.invoices
              .map(
                (invoice) => Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        color: AppColors.slate,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invoice.id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Jatuh tempo ${invoice.dueDate}',
                              style: const TextStyle(
                                color: AppColors.slate,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Rp ${formatErpCurrency(invoice.outstandingAmount)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
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
