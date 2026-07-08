import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_range_presets.dart';
import 'collection/ar_aging_tab.dart';
import 'collection/outstanding_invoice_tab.dart';
import 'collection/customer_payment_schedule_tab.dart';
import 'sales_ui.dart';

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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _CollectionFilterPanel(
                companies: companies,
                selectedCompany: selectedCompany,
                range: _range,
                dateBasis: _dateBasis,
                applyDateFilter: _applyDateFilter,
                onChanged: (company) {
                  context.read<AppState>().setSellingPeriod(
                    year: state.sellingPeriodYear,
                    month: state.sellingPeriodMonth,
                    company: company,
                  );
                },
                onDateBasisChanged: (value) =>
                    setState(() => _dateBasis = value),
                onApplyDateFilterChanged: (value) =>
                    setState(() => _applyDateFilter = value),
                onPickRange: _pickRange,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SalesPillTabBar(
                tabs: const [
                  Tab(text: 'AR Aging'),
                  Tab(text: 'Invoice'),
                  Tab(text: 'Janji Bayar'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ArAgingTab(
                    key: ValueKey(
                      'ar-$selectedCompany-${_range.from}-${_range.to}-$_dateBasis-$_applyDateFilter',
                    ),
                    range: _range,
                    dateBasis: _dateBasis,
                    applyDateFilter: _applyDateFilter,
                  ),
                  OutstandingInvoiceTab(
                    key: ValueKey(
                      'invoice-$selectedCompany-${_range.from}-${_range.to}-$_dateBasis-$_applyDateFilter',
                    ),
                    range: _range,
                    dateBasis: _dateBasis,
                    applyDateFilter: _applyDateFilter,
                  ),
                  CustomerPaymentScheduleTab(
                    key: ValueKey(
                      'schedule-$selectedCompany-${_range.from}-${_range.to}-$_dateBasis-$_applyDateFilter',
                    ),
                    range: _range,
                    dateBasis: _dateBasis,
                    applyDateFilter: _applyDateFilter,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _range.from, end: _range.to),
    );
    if (picked == null) return;
    setState(() {
      _range = DateRangePreset(from: picked.start, to: picked.end);
      _applyDateFilter = true;
    });
  }
}

class _CollectionFilterPanel extends StatelessWidget {
  const _CollectionFilterPanel({
    required this.companies,
    required this.selectedCompany,
    required this.range,
    required this.dateBasis,
    required this.applyDateFilter,
    required this.onChanged,
    required this.onDateBasisChanged,
    required this.onApplyDateFilterChanged,
    required this.onPickRange,
  });

  final List<String> companies;
  final String selectedCompany;
  final DateRangePreset range;
  final CollectionAgingDateBasis dateBasis;
  final bool applyDateFilter;
  final ValueChanged<String> onChanged;
  final ValueChanged<CollectionAgingDateBasis> onDateBasisChanged;
  final ValueChanged<bool> onApplyDateFilterChanged;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _CollectionIconTile(
                icon: Icons.business_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: companies.contains(selectedCompany)
                        ? selectedCompany
                        : null,
                    hint: const Text('Pilih Company'),
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.slate,
                    ),
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                    items: companies
                        .map(
                          (company) => DropdownMenuItem(
                            value: company,
                            child: Text(
                              company,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null || value.isEmpty) return;
                      onChanged(value);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
              Switch(
                value: applyDateFilter,
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
                  onTap: () =>
                      onDateBasisChanged(CollectionAgingDateBasis.invoiceDate),
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
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onPickRange,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
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
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 19),
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
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
