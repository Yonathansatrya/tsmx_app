import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/date_range_presets.dart';
import '../../../widgets/erp/erp_filter_tools.dart';
import 'ar_aging_tab.dart';
import 'outstanding_invoice_tab.dart';
import 'customer_payment_schedule_tab.dart';
import '../shared/sales_ui.dart';

class SalesCollectionTab extends StatefulWidget {
  const SalesCollectionTab({super.key});

  @override
  State<SalesCollectionTab> createState() => _SalesCollectionTabState();
}

class _SalesCollectionTabState extends State<SalesCollectionTab> {
  DateRangePreset _range = DateRangePresets.monthToDateRange();
  CollectionAgingDateBasis _dateBasis = CollectionAgingDateBasis.invoiceDate;
  bool _applyDateFilter = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    final companies = state.sellingCompanies;
    if (state.sellingCompanyFilter.isEmpty && companies.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final current = context.read<AppState>();
        if (current.sellingCompanyFilter.isNotEmpty) return;
        final preferred = current.preferredCompany(current.sellingCompanies);
        if (preferred == null || preferred.isEmpty) return;
        current.setSellingPeriod(
          year: current.sellingPeriodYear,
          month: current.sellingPeriodMonth,
          company: preferred,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final companies = state.sellingCompanies;
    final selectedCompany = state.sellingCompanyFilter.isNotEmpty
        ? state.sellingCompanyFilter
        : (state.preferredCompany(companies) ?? '');
    return DefaultTabController(
      length: 3,
      child: ColoredBox(
        color: AppColors.background,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                child: Column(
                  children: [
                    ErpPeriodFilterCard(
                      title: 'Filter Koleksi',
                      subtitle:
                          'Outstanding invoice mengikuti periode dan company ERPNext',
                      icon: Icons.payments_rounded,
                      selectedYear: state.sellingPeriodYear,
                      selectedMonth: state.sellingPeriodMonth,
                      loading: false,
                      showLoadingIndicator: state.isOrderSummaryLoading,
                      companyOptions: companies,
                      selectedCompany: selectedCompany,
                      onChanged: (year, month) =>
                          _setPeriod(year: year, month: month),
                      onCompanyChanged: (company) => _setPeriod(
                        year: state.sellingPeriodYear,
                        month: state.sellingPeriodMonth,
                        company: company,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CollectionAgingFilterPanel(
                      range: _range,
                      dateBasis: _dateBasis,
                      applyDateFilter: _applyDateFilter,
                      onDateBasisChanged: (value) => setState(() {
                        _dateBasis = value;
                        _applyDateFilter = true;
                      }),
                      onApplyDateFilterChanged: (value) =>
                          setState(() => _applyDateFilter = value),
                      onPickRange: _pickRange,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SalesPillTabBar(
                  tabs: const [
                    Tab(text: 'AR Aging'),
                    Tab(text: 'Invoice'),
                    Tab(text: 'Janji Bayar'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              ArAgingTab(
                key: ValueKey('ar-$selectedCompany'),
                range: _range,
                dateBasis: _dateBasis,
                applyDateFilter: _applyDateFilter,
              ),
              OutstandingInvoiceTab(
                key: ValueKey('invoice-$selectedCompany'),
                range: _range,
                dateBasis: _dateBasis,
                applyDateFilter: _applyDateFilter,
              ),
              CustomerPaymentScheduleTab(
                key: ValueKey('schedule-$selectedCompany'),
                range: _range,
                dateBasis: _dateBasis,
                applyDateFilter: _applyDateFilter,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickRange() async {
    if (!_applyDateFilter) {
      setState(() => _applyDateFilter = true);
    }
    final today = DateTime.now();
    final lastDate = _range.to.isAfter(today) ? _range.to : today;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: lastDate,
      initialDateRange: DateTimeRange(start: _range.from, end: _range.to),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _range = DateRangePreset(from: picked.start, to: picked.end);
      _applyDateFilter = true;
    });
  }

  void _setPeriod({required int year, required int month, String? company}) {
    context.read<AppState>().setSellingPeriod(
      year: year,
      month: month,
      company: company,
      documentType: 'Sales Invoice',
    );
    setState(() {
      _range = _rangeForPeriod(year, month);
      _applyDateFilter = false;
    });
  }

  DateRangePreset _rangeForPeriod(int year, int month) {
    if (month == 0) {
      return DateRangePreset(from: DateTime(year), to: DateTime(year, 12, 31));
    }
    return DateRangePreset(
      from: DateTime(year, month, 1),
      to: DateTime(year, month + 1, 0),
    );
  }
}

class _CollectionAgingFilterPanel extends StatelessWidget {
  const _CollectionAgingFilterPanel({
    required this.range,
    required this.dateBasis,
    required this.applyDateFilter,
    required this.onDateBasisChanged,
    required this.onApplyDateFilterChanged,
    required this.onPickRange,
  });

  final DateRangePreset range;
  final CollectionAgingDateBasis dateBasis;
  final bool applyDateFilter;
  final ValueChanged<CollectionAgingDateBasis> onDateBasisChanged;
  final ValueChanged<bool> onApplyDateFilterChanged;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: applyDateFilter ? 1 : 0.78,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.07),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const _CollectionIconTile(
                  icon: Icons.filter_alt_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filter Aging Piutang',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Pakai tanggal SI atau tanggal tukar faktur',
                        style: TextStyle(
                          color: AppColors.slate,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: applyDateFilter,
                  activeThumbColor: AppColors.white,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: AppColors.white,
                  inactiveTrackColor: AppColors.border,
                  onChanged: onApplyDateFilterChanged,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _FilterChipButton(
                    label: 'Tanggal SI',
                    selected: dateBasis == CollectionAgingDateBasis.invoiceDate,
                    onTap: () => onDateBasisChanged(
                      CollectionAgingDateBasis.invoiceDate,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FilterChipButton(
                    label: 'Tanggal TT',
                    selected:
                        dateBasis == CollectionAgingDateBasis.tukarFakturDate,
                    onTap: () => onDateBasisChanged(
                      CollectionAgingDateBasis.tukarFakturDate,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Material(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onPickRange,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.date_range_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${DateRangePresets.toFrappeDate(range.from)} s/d '
                          '${DateRangePresets.toFrappeDate(range.to)}',
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.slate,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.softGreen,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: selected ? 0 : 0.18),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.white : AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
