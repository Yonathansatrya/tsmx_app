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
import '../sales_ui.dart';

enum CollectionAgingDateBasis { invoiceDate, tukarFakturDate }

class _CollectionSurfaceCard extends StatelessWidget {
  const _CollectionSurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: SalesUi.cardDecoration(),
      child: child,
    );
  }
}

class _CollectionIconTile extends StatelessWidget {
  const _CollectionIconTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class ArAgingTab extends StatefulWidget {
  const ArAgingTab({
    super.key,
    required this.range,
    required this.dateBasis,
    required this.applyDateFilter,
  });

  final DateRangePreset range;
  final CollectionAgingDateBasis dateBasis;
  final bool applyDateFilter;

  @override
  State<ArAgingTab> createState() => _ArAgingTabState();
}

class _ArAgingTabState extends State<ArAgingTab> {
  List<SalesInvoice> outstanding = const [];
  List<CollectionPayment> payments = const [];
  Map<String, List<SalesInvoicePaymentAllocation>> invoicePaymentAllocations =
      const {};
  bool loading = true;
  String? agingError;
  String? paymentError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant ArAgingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range.from != widget.range.from ||
        oldWidget.range.to != widget.range.to ||
        oldWidget.dateBasis != widget.dateBasis ||
        oldWidget.applyDateFilter != widget.applyDateFilter) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      agingError = null;
      paymentError = null;
    });
    final state = context.read<AppState>();
    await Future.wait([
      () async {
        try {
          outstanding = await state.fetchCollectionOutstandingInvoices();
          invoicePaymentAllocations = await state
              .fetchSalesInvoicePaymentAllocations(
                outstanding.map((invoice) => invoice.id),
              );
        } catch (error) {
          agingError = error.toString();
        }
      }(),
      () async {
        try {
          payments = await state.fetchCollectionPayments(
            from: widget.range.from,
            to: widget.range.to,
          );
        } catch (error) {
          paymentError = error.toString();
        }
      }(),
    ]);
    if (mounted) setState(() => loading = false);
  }

  List<SalesInvoice> get filteredOutstanding {
    if (!widget.applyDateFilter) return outstanding;
    return outstanding.where((invoice) {
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
    for (final invoice in filteredOutstanding) {
      final due = DateTime.tryParse(invoice.collectionDueDate);
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

  double get totalOutstanding => filteredOutstanding.fold(
    0,
    (sum, invoice) => sum + invoice.outstandingAmount,
  );

  double get totalOverdue {
    final today = DateTime.now();
    return filteredOutstanding.fold(0, (sum, invoice) {
      final due = DateTime.tryParse(invoice.collectionDueDate);
      return due != null && due.isBefore(today)
          ? sum + invoice.outstandingAmount
          : sum;
    });
  }

  double get totalPayments =>
      payments.fold(0, (sum, payment) => sum + payment.amount);

  @override
  Widget build(BuildContext context) {
    final invoices = filteredOutstanding;
    return RefreshIndicator(
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
          const SizedBox(height: 14),
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
              child: _CollectionSurfaceCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colors[index].withValues(alpha: 0.1),
                      foregroundColor: colors[index],
                      child: Text('${index + 1}'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Rp ${formatErpCurrency(entry.value)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: colors[index],
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 18),

          const CollectionSectionHeader(
            title: 'Invoice Belum Dibayar',
            subtitle: 'Menampilkan tgl SI, tgl TT, dan jatuh tempo dari TT',
            icon: Icons.receipt_long_rounded,
          ),
          if (!loading && agingError == null && invoices.isEmpty)
            const ErpEmptyState(title: 'Tidak ada invoice pada filter ini')
          else
            ...invoices.map(
              (invoice) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CollectionInvoiceCard(
                  invoice: invoice,
                  allocations:
                      invoicePaymentAllocations[invoice.id] ?? const [],
                ),
              ),
            ),

          const SizedBox(height: 18),
          CollectionSectionHeader(
            title: 'Histori Pembayaran',
            subtitle: 'Pembayaran customer pada periode terpilih',
            icon: Icons.history_rounded,
          ),
          if (paymentError != null)
            ErpErrorBox(message: paymentError!)
          else if (!loading && payments.isEmpty)
            const ErpEmptyState(title: 'Belum ada pembayaran pada periode ini')
          else
            ...payments.map(
              (payment) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CollectionPaymentCard(payment: payment),
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
}

class _CollectionPaymentCard extends StatelessWidget {
  const _CollectionPaymentCard({required this.payment});

  final CollectionPayment payment;

  @override
  Widget build(BuildContext context) {
    final references = payment.salesInvoiceReferences.toList();
    final allocated = payment.allocatedToSalesInvoices;
    final unallocated = payment.unallocatedAmount;
    final isAllocated = payment.isAllocatedToSalesInvoice;
    return _CollectionSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CollectionIconTile(
            icon: isAllocated
                ? Icons.payments_outlined
                : Icons.priority_high_rounded,
            color: isAllocated ? AppColors.primary : AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.customerName,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${payment.postingDate} | ${payment.id}',
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    CollectionStatusChip(
                      label: isAllocated ? 'Teralokasi SI' : 'Belum alokasi SI',
                      color: isAllocated
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    if (allocated > 0)
                      CollectionStatusChip(
                        label: 'Alokasi Rp ${formatErpCurrency(allocated)}',
                        color: AppColors.primary,
                      ),
                    if (unallocated > 0)
                      CollectionStatusChip(
                        label:
                            'Belum alokasi Rp ${formatErpCurrency(unallocated)}',
                        color: AppColors.warning,
                      ),
                  ],
                ),
                if (references.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Invoice: ${references.map((reference) => '${reference.documentName} (Rp ${formatErpCurrency(reference.allocatedAmount)})').join(', ')}',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Rp ${formatErpCurrency(payment.amount)}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionInvoiceCard extends StatelessWidget {
  const _CollectionInvoiceCard({
    required this.invoice,
    required this.allocations,
  });

  final SalesInvoice invoice;
  final List<SalesInvoicePaymentAllocation> allocations;

  @override
  Widget build(BuildContext context) {
    final dueDate = invoice.collectionDueDate;
    final hasTukarFaktur =
        invoice.tukarFakturDate.trim().isNotEmpty ||
        invoice.tukarFaktur.trim().isNotEmpty;
    final allocated = allocations.fold<double>(
      0,
      (sum, allocation) => sum + allocation.allocatedAmount,
    );
    return _CollectionSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _CollectionIconTile(
                icon: Icons.description_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoice.id,
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
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _InvoiceDateLine(label: 'Tgl SI', value: invoice.date),
          _InvoiceDateLine(
            label: 'Tgl TT',
            value: hasTukarFaktur ? invoice.tukarFakturDate : '-',
          ),
          _InvoiceDateLine(
            label: 'Jatuh Tempo TT',
            value: dueDate.isEmpty ? '-' : dueDate,
          ),
          if (invoice.tukarFaktur.trim().isNotEmpty)
            _InvoiceDateLine(label: 'No TT', value: invoice.tukarFaktur),
          if (allocated > 0) ...[
            const Divider(height: 18),
            _InvoiceDateLine(
              label: 'Terbayar',
              value: 'Rp ${formatErpCurrency(allocated)}',
            ),
            ...allocations
                .take(3)
                .map(
                  (allocation) => _InvoiceDateLine(
                    label: allocation.postingDate.isEmpty
                        ? 'Payment'
                        : allocation.postingDate,
                    value:
                        '${allocation.paymentEntry} | Rp ${formatErpCurrency(allocation.allocatedAmount)}',
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _InvoiceDateLine extends StatelessWidget {
  const _InvoiceDateLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
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
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
