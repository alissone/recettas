/// Formats a DateTime as YYYY-MM-DD, the wire format for every `date`
/// column in the schema.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Today at midnight.
DateTime today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// "05/03".
String formatDayMonth(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}';

const List<String> kMonthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

const List<String> kWeekdaysShort = [
  'seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom',
];

/// "Março 2026".
String formatMonthYear(DateTime d) =>
    '${kMonthNames[d.month - 1]} ${d.year}';
