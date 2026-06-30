import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/sales_invoice.dart';
import '../../../models/sales_workspace.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/date_range_presets.dart';
import '../../../utils/erp_format.dart';
import '../../../widgets/erp/erp_empty_state.dart';
import '../../../widgets/erp/erp_error_box.dart';
import 'collection_widgets.dart';

class ArAgingTab extends StatefulWidget {
  const ArAgingTab({super.key});

  @override
  State<ArAgingTab> createState() => _ArAgingTabState();
}

class _ArAgingTabState extends State<ArAgingTab> {
  List<SalesInvoice> outstanding = const [];
  List<CollectionPayment> payments = const [];
  late DateRangePreset range;
  bool loading = true;
  String? agingError;
  String? paymentError;

  @override
  void initState() {
    super.initState();
    range = DateRangePresets.monthToDateRange();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      agingError = null;
      paymentError = null;
    });
    final state = context.read<AppState>();
    await Future.wait([
      state.fetchCollectionOutstandingInvoices().then(
        (value) => outstanding = value,
        onError: (Object error) => agingError = error.toString(),
      ),
      state.fetchCollectionPayments(from: range.from, to: range.to).then((
        value,
      ) {
        payments = value;
      }, onError: (Object error) => paymentError = error.toString()),
    ]);
    if (mounted) setState(() => loading = false);
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: range.from, end: range.to),
    );
    if (picked == null) return;
    setState(() => range = DateRangePreset(from: picked.start, to: picked.end));
    await _load();
  }

  Map<String, double> get agingBuckets {
    final buckets = <String, double>{
      'Sudah terlambat': 0,
      'Jatuh tempo hari ini': 0,
      'H-1': 0,
      'H-2 sampai H-7': 0,
      'H-8 sampai H-14': 0,
      'H-15 sampai H-25': 0,
      'H-26 sampai H-30': 0,
    };
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final invoice in outstanding) {
      final due = DateTime.tryParse(invoice.dueDate);
      if (due == null) continue;
      final days = due.difference(today).inDays;
      final key = days < 0
          ? 'Sudah terlambat'
          : days == 0
          ? 'Jatuh tempo hari ini'
          : days == 1
          ? 'H-1'
          : days <= 7
          ? 'H-2 sampai H-7'
          : days <= 14
          ? 'H-8 sampai H-14'
          : days <= 25
          ? 'H-15 sampai H-25'
          : 'H-26 sampai H-30';
      buckets[key] = buckets[key]! + invoice.outstandingAmount;
    }
    return buckets;
  }

  double get totalOutstanding =>
      outstanding.fold(0, (sum, invoice) => sum + invoice.outstandingAmount);

  double get totalOverdue {
    final today = DateTime.now();
    return outstanding.fold(0, (sum, invoice) {
      final due = DateTime.tryParse(invoice.dueDate);
      return due != null && due.isBefore(today)
          ? sum + invoice.outstandingAmount
          : sum;
    });
  }

  double get totalPayments =>
      payments.fold(0, (sum, payment) => sum + payment.amount);

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        const CollectionSectionHeader(
          title: 'Ringkasan Collection',
          subtitle: 'Pantau piutang dan pembayaran dengan cepat',
          icon: Icons.insights_rounded,
        ),
        Row(
          children: [
            Expanded(
              child: CollectionMetricCard(
                label: 'Total Piutang',
                value: 'Rp ${formatErpCurrency(totalOutstanding)}',
                icon: Icons.account_balance_wallet_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CollectionMetricCard(
                label: 'Sudah Overdue',
                value: 'Rp ${formatErpCurrency(totalOverdue)}',
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        CollectionMetricCard(
          label: 'Pembayaran pada periode terpilih',
          value: 'Rp ${formatErpCurrency(totalPayments)}',
          icon: Icons.payments_rounded,
          color: AppColors.success,
        ),
        if (loading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (agingError != null) ...[
          const SizedBox(height: 12),
          ErpErrorBox(message: agingError!),
        ],
        const SizedBox(height: 24),
        const CollectionSectionHeader(
          title: 'Jadwal Penagihan',
          subtitle: 'Dikelompokkan dari due date dan payment term customer',
          icon: Icons.timelapse_rounded,
        ),
        ...agingBuckets.entries.indexed.map((indexed) {
          final index = indexed.$1;
          final entry = indexed.$2;
          final colors = [
            AppColors.danger,
            AppColors.warning,
            const Color(0xFFEA580C),
            const Color(0xFFEA580C),
            AppColors.primary,
            AppColors.primaryLight,
            AppColors.success,
          ];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colors[index].withValues(alpha: 0.1),
                  foregroundColor: colors[index],
                  child: Text('${index + 1}'),
                ),
                title: Text(
                  entry.key,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing: Text(
                  'Rp ${formatErpCurrency(entry.value)}',
                  style: TextStyle(
                    color: colors[index],
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 18),
        CollectionSectionHeader(
          title: 'Histori Pembayaran',
          subtitle: 'Pembayaran customer pada periode terpilih',
          icon: Icons.history_rounded,
          trailing: IconButton.filledTonal(
            tooltip: 'Pilih periode',
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_rounded),
          ),
        ),
        if (paymentError != null)
          ErpErrorBox(message: paymentError!)
        else if (!loading && payments.isEmpty)
          const ErpEmptyState(title: 'Belum ada pembayaran pada periode ini')
        else
          ...payments.map(
            (payment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.softGreen,
                    foregroundColor: AppColors.primary,
                    child: Icon(Icons.payments_outlined),
                  ),
                  title: Text(
                    payment.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${payment.postingDate} • ${payment.id}'
                    '${payment.references.isEmpty ? '' : '\nInvoice: ${payment.references.map((reference) => reference.documentName).join(', ')}'}',
                  ),
                  isThreeLine: payment.references.isNotEmpty,
                  trailing: Text(
                    'Rp ${formatErpCurrency(payment.amount)}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (agingError != null || paymentError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Muat ulang data'),
            ),
          ),
      ],
    ),
  );
}
