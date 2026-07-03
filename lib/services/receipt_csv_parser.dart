/// Parses the CSV the vision model returns for a receipt photo.
///
/// Port of the parsing logic from the cupom-scanner.html tool: handles
/// alternate delimiters (;, |), values split by decimal commas, and
/// DD/MM/YYYY → YYYY-MM-DD date normalization.
library;

class ReceiptItem {
  final String nome;
  final double quantidade;
  final double valorUnitario;

  /// YYYY-MM-DD when the model returned a valid date, otherwise ''.
  final String data;
  final String estabelecimento;

  const ReceiptItem({
    required this.nome,
    required this.quantidade,
    required this.valorUnitario,
    required this.data,
    required this.estabelecimento,
  });

  double get valorTotal =>
      double.parse((quantidade * valorUnitario).toStringAsFixed(2));
}

class ReceiptCsvParser {
  ReceiptCsvParser._();

  static final _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static bool isValidDate(String s) => _dateRe.hasMatch(s);

  /// Strips markdown code fences and `<think>` blocks from model output.
  static String cleanModelOutput(String raw) {
    var s = raw;
    s = s.replaceAll(RegExp(r'<think>[\s\S]*?</think>\s*'), '');
    s = s.replaceFirst(RegExp(r'^```(?:csv)?\s*\n?', caseSensitive: false), '');
    s = s.replaceFirst(RegExp(r'\n?```\s*$'), '');
    return s.trim();
  }

  /// The model sometimes uses ; or | as delimiter; convert to commas.
  static String normalizeDelimiter(String csv) {
    final first = csv.split('\n').firstOrNull ?? '';
    String delim = ',';
    if (first.contains(';') && !first.contains(',')) {
      delim = ';';
    } else if (first.contains('|') &&
        !first.contains(',') &&
        !first.contains(';')) {
      delim = '|';
    }
    if (delim == ',') return csv;
    return csv.split('\n').map((line) {
      final parts = line.split(delim).map((f) => f.trim());
      return parts.map((f) => f.contains(',') ? '"$f"' : f).join(',');
    }).join('\n');
  }

  /// Quote-aware split of a single CSV line.
  static List<String> parseLine(String line) {
    final result = <String>[];
    final current = StringBuffer();
    var inQuotes = false;
    for (final ch in line.split('')) {
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(ch);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  /// Expected: [NOME, QUANTIDADE, VALOR, DATA, ESTABELECIMENTO] = 5 fields.
  /// When the model used a decimal comma in VALOR the field gets split;
  /// merge the middle pieces back together.
  static List<String> fixDecimalCommas(List<String> fields) {
    final digits = RegExp(r'^\d+$');
    if (fields.length == 6 &&
        digits.hasMatch(fields[2]) &&
        digits.hasMatch(fields[3])) {
      return [
        fields[0],
        fields[1],
        '${fields[2]}.${fields[3]}',
        fields[4],
        fields[5],
      ];
    }
    if (fields.length > 6) {
      return [
        fields[0],
        fields[1],
        fields.sublist(2, fields.length - 2).join('.'),
        fields[fields.length - 2],
        fields[fields.length - 1],
      ];
    }
    return fields;
  }

  /// DD/MM/YYYY → YYYY-MM-DD; anything else passes through.
  static String normalizeDate(String val) {
    if (!val.contains('/')) return val.trim();
    final parts = val.trim().split('/');
    if (parts.length != 3) return val.trim();
    final d = parts[0].padLeft(2, '0');
    final m = parts[1].padLeft(2, '0');
    return '${parts[2]}-$m-$d';
  }

  static List<ReceiptItem> parse(String rawModelOutput) {
    final csv = normalizeDelimiter(cleanModelOutput(rawModelOutput));
    final lines =
        csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    // Skip the header row when present.
    final firstLower = lines.first.toLowerCase();
    final dataLines = (firstLower.contains('nome') ||
            firstLower.contains('quantidade') ||
            firstLower.contains('valor'))
        ? lines.sublist(1)
        : lines;

    final items = <ReceiptItem>[];
    for (final line in dataLines) {
      final fields = fixDecimalCommas(parseLine(line));
      if (fields.length < 5) continue;
      final date = normalizeDate(fields[3]);
      items.add(ReceiptItem(
        nome: fields[0],
        quantidade: double.tryParse(fields[1].replaceAll(',', '.')) ?? 1,
        valorUnitario:
            double.tryParse(fields[2].replaceAll(',', '.')) ?? 0,
        data: isValidDate(date) ? date : '',
        estabelecimento: fields[4],
      ));
    }
    return items;
  }
}
