class NumParse {
  static int asInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    final text = value.toString().trim();
    if (text.isEmpty) return fallback;
    final asDouble = double.tryParse(text);
    if (asDouble != null) return asDouble.round();
    return int.tryParse(text) ?? fallback;
  }

  static double asDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    var text = value.toString().trim();
    if (text.isEmpty) return fallback;
    final direct = double.tryParse(text);
    if (direct != null) return direct;

    text = text
        .replaceAll(RegExp(r'[^0-9,.\-]'), '')
        .replaceAll(RegExp(r'(?<!^)-'), '');
    if (text.isEmpty || text == '-') return fallback;

    final lastComma = text.lastIndexOf(',');
    final lastDot = text.lastIndexOf('.');
    if (lastComma >= 0 && lastDot >= 0) {
      final decimalSeparator = lastComma > lastDot ? ',' : '.';
      final thousandsSeparator = decimalSeparator == ',' ? '.' : ',';
      text = text
          .replaceAll(thousandsSeparator, '')
          .replaceAll(decimalSeparator, '.');
    } else if (lastComma >= 0) {
      final decimalDigits = text.length - lastComma - 1;
      text = decimalDigits == 3
          ? text.replaceAll(',', '')
          : text.replaceAll(',', '.');
    } else if (lastDot >= 0) {
      final decimalDigits = text.length - lastDot - 1;
      if (decimalDigits == 3) text = text.replaceAll('.', '');
    }

    return double.tryParse(text) ?? fallback;
  }
}
