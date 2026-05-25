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
    final text = value.toString().trim();
    if (text.isEmpty) return fallback;
    return double.tryParse(text) ?? fallback;
  }
}
