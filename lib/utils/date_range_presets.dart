class DateRangePreset {
  final DateTime from;
  final DateTime to;

  const DateRangePreset({required this.from, required this.to});
}

enum StockDatePresetId { monthToDate, last7Days, last30Days, custom }

class DateRangePresets {
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateRangePreset monthToDateRange({DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    return DateRangePreset(
      from: DateTime(today.year, today.month, 1),
      to: today,
    );
  }

  static DateRangePreset last7DaysRange({DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    return DateRangePreset(
      from: today.subtract(const Duration(days: 6)),
      to: today,
    );
  }

  static DateRangePreset last30DaysRange({DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    return DateRangePreset(
      from: today.subtract(const Duration(days: 29)),
      to: today,
    );
  }

  static String toFrappeDate(DateTime d) {
    final normalized = _dateOnly(d);
    return '${normalized.year.toString().padLeft(4, '0')}-'
        '${normalized.month.toString().padLeft(2, '0')}-'
        '${normalized.day.toString().padLeft(2, '0')}';
  }

  static String formatDisplay(DateTime d) {
    final normalized = _dateOnly(d);
    return '${normalized.day.toString().padLeft(2, '0')}/'
        '${normalized.month.toString().padLeft(2, '0')}/'
        '${normalized.year}';
  }

  static String formatRangeLabel(DateRangePreset range) {
    return '${formatDisplay(range.from)} – ${formatDisplay(range.to)}';
  }
}
