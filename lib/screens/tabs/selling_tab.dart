import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/erp/erp_segment_bar.dart';
import 'selling/sales_order_panel.dart';
import 'selling/delivery_note_panel.dart';
import 'selling/sales_invoice_panel.dart';

class SellingTab extends StatefulWidget {
  final String selectedSegment;
  final ValueChanged<String>? onSegmentChanged;

  const SellingTab({
    super.key,
    required this.selectedSegment,
    this.onSegmentChanged,
  });

  @override
  State<SellingTab> createState() => SellingTabState();
}

class SellingTabState extends State<SellingTab> {
  static const segments = [
    ErpSegmentOption(id: 'so', label: 'Sales Order'),
    ErpSegmentOption(id: 'dn', label: 'Delivery Notes'),
    ErpSegmentOption(id: 'si', label: 'Invoices'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      appState.refreshSellingSummaries();
      if (appState.salesOrders.isEmpty) appState.refreshSalesOrders();
      if (appState.deliveryNotes.isEmpty) appState.refreshDeliveryNotes();
      if (appState.salesInvoices.isEmpty) appState.refreshSalesInvoices();
    });
  }

  Future<void> refreshCurrent() async {
    final appState = context.read<AppState>();
    await Future.wait([
      appState.refreshSellingSummaries(),
      switch (widget.selectedSegment) {
        'dn' => appState.refreshDeliveryNotes(),
        'si' => appState.refreshSalesInvoices(),
        _ => appState.refreshSalesOrders(),
      },
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: refreshCurrent,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter > 320) return false;
          final appState = context.read<AppState>();
          switch (widget.selectedSegment) {
            case 'dn':
              appState.loadMoreDeliveryNotes();
            case 'si':
              appState.loadMoreSalesInvoices();
            case 'so':
            default:
              appState.loadMoreSalesOrders();
          }
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            _SellingPeriodFilter(
              selectedYear: appState.sellingPeriodYear,
              selectedMonth: appState.sellingPeriodMonth,
              loading: appState.isOrderSummaryLoading,
              onChanged: (year, month) => context
                  .read<AppState>()
                  .setSellingPeriod(year: year, month: month),
            ),
            const SizedBox(height: 12),
            ErpSegmentBar(
              options: segments,
              selectedId: widget.selectedSegment,
              onSelected: (id) {
                widget.onSegmentChanged?.call(id);
                final appState = context.read<AppState>();
                switch (id) {
                  case 'dn':
                    if (appState.deliveryNotes.isEmpty) {
                      appState.refreshDeliveryNotes();
                    }
                    break;
                  case 'si':
                    if (appState.salesInvoices.isEmpty) {
                      appState.refreshSalesInvoices();
                    }
                    break;
                  case 'so':
                  default:
                    if (appState.salesOrders.isEmpty) {
                      appState.refreshSalesOrders();
                    }
                }
              },
            ),
            const SizedBox(height: 14),
            switch (widget.selectedSegment) {
              'dn' => const DeliveryNotePanel(),
              'si' => const SalesInvoicePanel(),
              _ => const SalesOrderPanel(),
            },
          ],
        ),
      ),
    );
  }
}

class _SellingPeriodFilter extends StatelessWidget {
  final int selectedYear;
  final int selectedMonth;
  final bool loading;
  final void Function(int year, int month) onChanged;

  const _SellingPeriodFilter({
    required this.selectedYear,
    required this.selectedMonth,
    required this.loading,
    required this.onChanged,
  });

  static const _monthLabels = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = [
      for (var year = currentYear; year >= currentYear - 5; year--) year,
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Periode Selling',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Data dan total Rp mengikuti bulan ini',
                      style: TextStyle(
                        color: AppColors.slate,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  initialValue: selectedMonth,
                  decoration: const InputDecoration(labelText: 'Bulan'),
                  items: [
                    for (var i = 0; i < _monthLabels.length; i++)
                      DropdownMenuItem(
                        value: i + 1,
                        child: Text(_monthLabels[i]),
                      ),
                  ],
                  onChanged: loading
                      ? null
                      : (value) {
                          if (value == null) return;
                          onChanged(selectedYear, value);
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  initialValue: selectedYear,
                  decoration: const InputDecoration(labelText: 'Tahun'),
                  items: [
                    for (final year in years)
                      DropdownMenuItem(value: year, child: Text('$year')),
                  ],
                  onChanged: loading
                      ? null
                      : (value) {
                          if (value == null) return;
                          onChanged(value, selectedMonth);
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
