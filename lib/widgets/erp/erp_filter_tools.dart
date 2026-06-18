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

  const ErpPeriodFilterCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selectedYear,
    required this.selectedMonth,
    required this.loading,
    required this.onChanged,
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: AppColors.cardShadow,
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  initialValue: selectedMonth,
                  decoration: const InputDecoration(
                    labelText: 'Bulan',
                    prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                  ),
                  items: [
                    for (var i = 0; i < monthLabels.length; i++)
                      DropdownMenuItem(
                        value: i + 1,
                        child: Text(monthLabels[i]),
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
