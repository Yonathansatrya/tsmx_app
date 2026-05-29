String formatErpCurrency(double val) {
  final strVal = val.toInt().toString();
  final buffer = StringBuffer();
  var count = 0;

  for (var i = strVal.length - 1; i >= 0; i--) {
    buffer.write(strVal[i]);
    count++;
    if (count == 3 && i > 0) {
      buffer.write('.');
      count = 0;
    }
  }

  return buffer.toString().split('').reversed.join('');
}
