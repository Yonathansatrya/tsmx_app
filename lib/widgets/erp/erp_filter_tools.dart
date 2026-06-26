import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class ErpPeriodFilterCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final int selectedYear;
  final int selectedMonth;
  final bool loading;
  final void Function(int year, int month) onChanged;
  final List<String> companyOptions;
  final String selectedCompany;
  final ValueChanged<String>? onCompanyChanged;
  final String selectedCustomerType;
  final ValueChanged<String>? onCustomerTypeChanged;
  final String partnerTypeLabel;
  final IconData partnerTypeIcon;

  const ErpPeriodFilterCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selectedYear,
    required this.selectedMonth,
    required this.loading,
    required this.onChanged,
    this.companyOptions = const [],
    this.selectedCompany = '',
    this.onCompanyChanged,
    this.selectedCustomerType = 'all',
    this.onCustomerTypeChanged,
    this.partnerTypeLabel = 'Customer',
    this.partnerTypeIcon = Icons.groups_2_rounded,
  });

  static const monthLabels = [
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
    final companies = [
      ...companyOptions,
      if (selectedCompany.isNotEmpty &&
          !companyOptions.contains(selectedCompany))
        selectedCompany,
    ]..sort();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
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
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final monthDropdown = DropdownButtonFormField<int>(
                initialValue: selectedMonth,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Bulan',
                  prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                ),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('Semua Bulan')),
                  for (var i = 0; i < monthLabels.length; i++)
                    DropdownMenuItem(
                      value: i + 1,
                      child: Text(
                        monthLabels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: loading
                    ? null
                    : (value) {
                        if (value == null) return;
                        onChanged(selectedYear, value);
                      },
              );
              final yearDropdown = DropdownButtonFormField<int>(
                initialValue: selectedYear,
                isExpanded: true,
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
              );

              if (compact) {
                return Column(
                  children: [
                    monthDropdown,
                    const SizedBox(height: 10),
                    yearDropdown,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: monthDropdown),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: yearDropdown),
                ],
              );
            },
          ),
          if (onCompanyChanged != null || onCustomerTypeChanged != null) ...[
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 390;
                final companyDropdown = onCompanyChanged == null
                    ? null
                    : DropdownButtonFormField<String>(
                        initialValue: selectedCompany,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Company',
                          prefixIcon: Icon(Icons.business_rounded, size: 18),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Semua Company'),
                          ),
                          for (final company in companies)
                            DropdownMenuItem(
                              value: company,
                              child: Text(
                                company,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: loading
                            ? null
                            : (value) => onCompanyChanged?.call(value ?? ''),
                      );
                final customerDropdown = onCustomerTypeChanged == null
                    ? null
                    : DropdownButtonFormField<String>(
                        initialValue: selectedCustomerType,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: partnerTypeLabel,
                          prefixIcon: Icon(partnerTypeIcon, size: 18),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Semua')),
                          DropdownMenuItem(
                            value: 'external',
                            child: Text('External'),
                          ),
                          DropdownMenuItem(
                            value: 'internal',
                            child: Text('Internal'),
                          ),
                        ],
                        onChanged: loading
                            ? null
                            : (value) =>
                                  onCustomerTypeChanged?.call(value ?? 'all'),
                      );

                if (compact) {
                  return Column(
                    children: [
                      ?companyDropdown,
                      if (companyDropdown != null && customerDropdown != null)
                        const SizedBox(height: 10),
                      ?customerDropdown,
                    ],
                  );
                }

                return Row(
                  children: [
                    if (companyDropdown != null)
                      Expanded(flex: 3, child: companyDropdown),
                    if (companyDropdown != null && customerDropdown != null)
                      const SizedBox(width: 10),
                    if (customerDropdown != null)
                      Expanded(flex: 2, child: customerDropdown),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
