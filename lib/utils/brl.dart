/// Formats 1234.5 as "R$ 1.234,50".
String formatBrl(double value) {
  final negative = value < 0;
  final parts = value.abs().toStringAsFixed(2).split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }
  return '${negative ? '-' : ''}R\$ $buf,${parts[1]}';
}

/// Parses user input like "12,34", "1.234,56", "R$ 5" or "12.34".
double? parseBrlInput(String input) {
  var t = input.replaceAll('R\$', '').trim();
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    // Brazilian format: dots are thousands separators.
    t = t.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(t);
}
