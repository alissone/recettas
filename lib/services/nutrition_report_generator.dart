import 'dart:math' as math;

import '../models/food.dart';
import '../models/nutrient.dart';
import '../models/nutrient_daily_values.dart';
import '../utils/dates.dart';
import 'report_generator.dart';

/// Builds the printable nutrition report for a hand-picked set of days as
/// a self-contained HTML document, in the same A4 style as the expense
/// report (ReportGenerator, whose CSS it reuses).
///
/// Per day: an overview page (calories and macros against their targets,
/// what was eaten, the energy split, and a ruled notes area to write on
/// after printing), then as many pages as it takes to chart every
/// nutrient group with data - macros, sugars, fatty acids, amino acids,
/// vitamins, minerals... When more than one day is picked, a period
/// summary page comes first.
class NutritionReportGenerator {
  NutritionReportGenerator._();

  static const _navy = '#1a2744';
  static const _gold = '#c9a84c';
  static const _muted = '#6b7a8d';
  static const _grey = '#94a3b8';

  static const _proteinColor = '#3b82f6';
  static const _carbColor = '#f59e0b';
  static const _fatColor = '#ef4444';
  static const _alcoholColor = '#8b5cf6';

  static const _metColor = '#10b981';
  static const _partialColor = '#60a5fa';
  static const _overColor = '#ef4444';
  static const _highColor = '#f97316';

  static const _weekdays = [
    'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira',
    'Sexta-feira', 'Sábado', 'Domingo',
  ];

  /// Food rows on a day's overview page before the rest are folded into
  /// one "+ N outros" line - the list is meant to be a short reminder.
  static const _maxFoodRows = 16;

  /// Nutrient bar rows that fit one column of a panel page; a group title
  /// costs [_titleRows].
  static const _rowsPerColumn = 54;
  static const _titleRows = 3;

  /// Period table rows that still fit under the summary chart; longer
  /// periods move the table to pages of their own.
  static const _summaryInlineRows = 20;
  static const _summaryRowsPerPage = 44;

  /// Shown on the overview page, so left out of the nutrient panels.
  static const _skipInPanels = {NutrientId.calories, NutrientId.kilojoules};

  static String _esc(Object? v) => ReportGenerator.escapeHtml(v);

  /// [days] must not be empty; [entries] may cover more than [days] and
  /// is filtered here. [targets] is the active recommendation set;
  /// targets missing from it fall back to the FDA Daily Values the same
  /// way the Nutrição screen does ([effectiveNutrientTarget]).
  static String buildReport({
    required List<DateTime> days,
    required List<FoodEntry> entries,
    required Map<NutrientId, Nutrient> catalog,
    required Map<NutrientId, double> targets,
    double? goalCalories,
  }) {
    final sortedDays = [...days]..sort();
    final now = DateTime.now();
    final nowStr = '${_fmtDate(now)} ${_two(now.hour)}:${_two(now.minute)}';
    final period = sortedDays.length == 1
        ? _fmtDate(sortedDays.first)
        : '${_fmtDate(sortedDays.first)} — ${_fmtDate(sortedDays.last)}';

    double? target(NutrientId id) {
      final t = effectiveNutrientTarget(id,
          targets: targets, goalCalories: goalCalories);
      return t != null && t > 0 ? t : null;
    }

    final dayData = [
      for (final day in sortedDays)
        _Day.from(day, entries.where((e) => e.entryDate == isoDate(day)))
    ];

    final pages = StringBuffer();
    var pageNum = 0;
    String footer() => _pageFooter(period, nowStr);

    // ── Period summary ───────────────────────────────────────────────
    if (dayData.length > 1) {
      final n = dayData.length;
      double avg(NutrientId id) =>
          dayData.fold(0.0, (s, d) => s + d.get(id)) / n;

      final rows = [for (final d in dayData) _summaryRow(d)];
      final inline = rows.length <= _summaryInlineRows;

      List<double> kcalOf(NutrientId id, double factor) =>
          [for (final d in dayData) d.get(id) * factor];
      final series = [
        ('Proteínas', _proteinColor, kcalOf(NutrientId.protein, 4)),
        ('Carboidratos', _carbColor, kcalOf(NutrientId.carbohydrates, 4)),
        ('Gorduras', _fatColor, kcalOf(NutrientId.fat, 9)),
      ];
      final kcalTarget = target(NutrientId.calories);
      final chartHeightMm = inline ? 80 : 160;
      final legend = StringBuffer();
      for (final s in series) {
        legend.write('<span><i style="background:${s.$2}"></i>'
            '${_esc(s.$1)}</span>');
      }
      if (kcalTarget != null) {
        legend.write('<span><i class="dash"></i>'
            'Meta (${kcalTarget.round()} kcal)</span>');
      }

      pages.write('''
<div class="page page-content">
  ${_pageHeader('Resumo do Período', '${++pageNum}', '$period · $n dias')}
  <div class="body">
    ${_macroKpis(
        kcal: avg(NutrientId.calories),
        protein: avg(NutrientId.protein),
        carbs: avg(NutrientId.carbohydrates),
        fat: avg(NutrientId.fat),
        target: target,
        prefix: 'Média ',
      )}
    <h3 class="section-title">Calorias por Dia (kcal, por macronutriente)</h3>
    <div class="svg-chart" style="height:${chartHeightMm}mm">
      ${_stackedBarsSvg(
        labels: [for (final d in dayData) _fmtDayMonth(d.day)],
        series: series,
        target: kcalTarget,
        height: chartHeightMm * 3.78,
      )}
    </div>
    <div class="panel-key chart-legend">$legend</div>
    ${inline ? _summaryTable(rows.join()) : ''}
  </div>
  ${footer()}
</div>''');

      if (!inline) {
        final chunks = (rows.length / _summaryRowsPerPage).ceil();
        for (var c = 0; c < chunks; c++) {
          pages.write('''
<div class="page page-content">
  ${_pageHeader('Resumo do Período — Dias', '${++pageNum}', 'Página ${c + 1} de $chunks')}
  <div class="body">
    ${_summaryTable(rows.skip(c * _summaryRowsPerPage).take(_summaryRowsPerPage).join())}
  </div>
  ${footer()}
</div>''');
        }
      }
    }

    // ── Per-day pages ────────────────────────────────────────────────
    for (var i = 0; i < dayData.length; i++) {
      final d = dayData[i];
      final dayTitle =
          '${_weekdays[d.day.weekday - 1]}, ${_fmtDate(d.day)}';
      final daySub = dayData.length > 1 ? 'Dia ${i + 1} de ${dayData.length}' : '';

      // Energy split by macro (kcal), the doughnut's data.
      final split = [
        ('Proteínas', d.get(NutrientId.protein) * 4, _proteinColor),
        ('Carboidratos', d.get(NutrientId.carbohydrates) * 4, _carbColor),
        ('Gorduras', d.get(NutrientId.fat) * 9, _fatColor),
        ('Álcool', d.get(NutrientId.alcohol) * 7, _alcoholColor),
      ].where((s) => s.$2 > 0).toList();
      final splitTotal = split.fold(0.0, (s, e) => s + e.$2);
      final splitLegend = StringBuffer();
      for (final s in split) {
        splitLegend.write('<div class="split-row">'
            '<span class="dot" style="background:${s.$3}"></span>'
            '<span class="split-name">${_esc(s.$1)}</span>'
            '<span class="split-val">${s.$2.round()} kcal · '
            '${(s.$2 / splitTotal * 100).round()}%</span></div>');
      }

      pages.write('''
<div class="page page-content">
  ${_pageHeader(dayTitle, '${++pageNum}', daySub)}
  <div class="body">
    ${_macroKpis(
        kcal: d.get(NutrientId.calories),
        protein: d.get(NutrientId.protein),
        carbs: d.get(NutrientId.carbohydrates),
        fat: d.get(NutrientId.fat),
        target: target,
      )}
    <div class="day-grid">
      <div class="day-foods">
        <h3 class="section-title">O que comeu</h3>
        ${_foodTable(d)}
      </div>
      <div class="day-split">
        <h3 class="section-title">Energia por Macro</h3>
        ${split.isEmpty ? '<p class="muted small">Sem dados de macronutrientes.</p>' : '''
        <div class="svg-chart" style="height:52mm">${_doughnutSvg(split)}</div>
        <div class="split-legend">$splitLegend</div>'''}
      </div>
    </div>
    <div class="notes">
      <h3 class="section-title">Anotações</h3>
      <div class="notes-lines"></div>
    </div>
  </div>
  ${footer()}
</div>''');

      // Nutrient panels, flowed into two columns per page.
      final columns = _panelColumns(d, catalog, target);
      for (var c = 0; c < columns.length; c += 2) {
        final pageOf = c ~/ 2 + 1;
        final pageCount = (columns.length / 2).ceil();
        pages.write('''
<div class="page page-content">
  ${_pageHeader('Nutrientes — ${_fmtDate(d.day)}', '${++pageNum}', pageCount > 1 ? 'Página $pageOf de $pageCount' : '')}
  <div class="body">
    <div class="panel-cols">
      <div class="panel-col">${columns[c]}</div>
      <div class="panel-col">${c + 1 < columns.length ? columns[c + 1] : ''}</div>
    </div>
    <div class="panel-key">
      <span><i style="background:$_metColor"></i>Meta atingida / abaixo do limite</span>
      <span><i style="background:$_partialColor"></i>Abaixo da meta</span>
      <span><i style="background:$_highColor"></i>Mais que o dobro da meta</span>
      <span><i style="background:$_overColor"></i>Acima do limite</span>
      <span><i style="background:$_grey"></i>Sem meta (relativo ao maior do grupo)</span>
    </div>
  </div>
  ${footer()}
</div>''');
      }
    }

    return '''<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=794">
<style>
${ReportGenerator.baseCss}
${_css()}
</style>
</head>
<body>
<button class="print-btn" onclick="window.print()">Imprimir / Salvar PDF</button>
$pages
<script>
// Only a real browser (the desktop fallback opens the report from a
// file) can print from the page; the in-app WebView and the PDF export
// leave the button hidden and use the app's own actions instead.
if (location.protocol === 'file:') document.body.classList.add('in-browser');
</script>
</body>
</html>''';
  }

  // ── Charts ────────────────────────────────────────────────────────
  // Inline SVG rather than Chart.js: the PDF export renders the page in
  // a WebView with JavaScript off (printing's convertHtml), where canvas
  // charts would come out blank.

  /// Energy split ring, one stroke-dashed circle per slice.
  static String _doughnutSvg(List<(String, double, String)> split) {
    const r = 38.0;
    const c = 2 * math.pi * r;
    final total = split.fold(0.0, (s, e) => s + e.$2);
    final gap = split.length > 1 ? 0.8 : 0.0;
    final arcs = StringBuffer();
    var offset = 0.0;
    for (final s in split) {
      final len = s.$2 / total * c;
      arcs.write('<circle cx="50" cy="50" r="$r" fill="none" '
          'stroke="${s.$3}" stroke-width="20" '
          'stroke-dasharray="${_n(math.max(len - gap, 0))} ${_n(c)}" '
          'stroke-dashoffset="${_n(-offset)}" '
          'transform="rotate(-90 50 50)"/>');
      offset += len;
    }
    return '<svg viewBox="0 0 100 100" width="100%" height="100%">'
        '$arcs</svg>';
  }

  /// Stacked columns per day with an optional dashed target line, drawn
  /// in a [height]-px-tall viewBox 700 px wide (the body width).
  static String _stackedBarsSvg({
    required List<String> labels,
    required List<(String, String, List<double>)> series,
    required double? target,
    required double height,
  }) {
    const width = 700.0;
    const left = 44.0, right = 8.0, top = 10.0, bottom = 22.0;
    final plotW = width - left - right;
    final plotH = height - top - bottom;
    final n = labels.length;

    var maxValue = target ?? 0;
    for (var i = 0; i < n; i++) {
      maxValue =
          math.max(maxValue, series.fold(0.0, (s, e) => s + e.$3[i]));
    }
    if (maxValue <= 0) maxValue = 1;
    final step = _niceStep(maxValue / 5);
    final axisMax = (maxValue / step).ceil() * step;
    double y(double v) => top + plotH - v / axisMax * plotH;

    final out = StringBuffer(
        '<svg viewBox="0 0 $width ${_n(height)}" width="100%" height="100%" '
        'font-family="Segoe UI, Roboto, Arial, sans-serif" font-size="10">');

    for (var v = 0.0; v <= axisMax + 0.001; v += step) {
      out.write('<line x1="$left" x2="${width - right}" y1="${_n(y(v))}" '
          'y2="${_n(y(v))}" stroke="#e2e8f0" stroke-width="1"/>'
          '<text x="${left - 6}" y="${_n(y(v) + 3.5)}" text-anchor="end" '
          'fill="$_muted">${v.round()}</text>');
    }

    final band = plotW / n;
    final barW = math.min(band * 0.62, 48.0);
    // Thin the x labels out so they never overlap (~34 px each).
    final labelEvery = math.max(1, (34 / band).ceil());
    for (var i = 0; i < n; i++) {
      final x = left + band * i + (band - barW) / 2;
      var acc = 0.0;
      for (final s in series) {
        final v = s.$3[i];
        if (v <= 0) continue;
        out.write('<rect x="${_n(x)}" y="${_n(y(acc + v))}" '
            'width="${_n(barW)}" height="${_n(y(acc) - y(acc + v))}" '
            'fill="${s.$2}"/>');
        acc += v;
      }
      if (i % labelEvery == 0) {
        out.write('<text x="${_n(left + band * i + band / 2)}" '
            'y="${_n(height - 6)}" text-anchor="middle" fill="$_muted">'
            '${_esc(labels[i])}</text>');
      }
    }

    if (target != null) {
      out.write('<line x1="$left" x2="${width - right}" '
          'y1="${_n(y(target))}" y2="${_n(y(target))}" stroke="$_navy" '
          'stroke-width="1.5" stroke-dasharray="6 4"/>');
    }
    out.write('</svg>');
    return out.toString();
  }

  /// 1, 2, 2.5 or 5 times a power of ten, at least [raw].
  static double _niceStep(double raw) {
    final mag =
        math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    for (final m in [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (m * mag >= raw) return m * mag;
    }
    return 10 * mag;
  }

  static String _n(double v) => v.toStringAsFixed(2);

  // ── Fragments ─────────────────────────────────────────────────────

  static String _macroKpis({
    required double kcal,
    required double protein,
    required double carbs,
    required double fat,
    required double? Function(NutrientId) target,
    String prefix = '',
  }) {
    String card(String label, double value, String unit, NutrientId id,
        String color, {double? kcalPerG}) {
      final t = target(id);
      final targetLine = t == null
          ? 'Sem meta'
          : '${(value / t * 100).round()}% de ${_fmtNum(t)} $unit';
      final energyLine = kcalPerG != null && kcal > 0
          ? ' · ${(value * kcalPerG / kcal * 100).round()}% kcal'
          : '';
      final pct = t == null ? 0.0 : math.min(value / t * 100, 100.0);
      return '''
<div class="kpi-card" style="border-top:3px solid $color">
  <div class="kpi-label">${_esc(prefix + label)}</div>
  <div class="kpi-value" style="color:$color">${_fmtNum(value)} <small>$unit</small></div>
  <div class="kpi-sub">${_esc(targetLine)}$energyLine</div>
  ${t == null ? '' : '<div class="kpi-bar"><div style="width:${pct.toStringAsFixed(1)}%;background:$color"></div></div>'}
</div>''';
    }

    return '''
<div class="kpi-grid">
  ${card('Calorias', kcal, 'kcal', NutrientId.calories, _gold)}
  ${card('Proteínas', protein, 'g', NutrientId.protein, _proteinColor, kcalPerG: 4)}
  ${card('Carboidratos', carbs, 'g', NutrientId.carbohydrates, _carbColor, kcalPerG: 4)}
  ${card('Gorduras', fat, 'g', NutrientId.fat, _fatColor, kcalPerG: 9)}
</div>''';
  }

  /// The day's foods in the order they were logged, repeats of the same
  /// food or recipe merged into one line.
  static String _foodTable(_Day d) {
    final merged = <String, _FoodLine>{};
    for (final e in d.entries) {
      final key = e.recipe?.id ?? e.food.id;
      final line = merged.putIfAbsent(
          key, () => _FoodLine(e.food.label, e.food.baseUnit));
      line.amount += e.amount;
      line.count++;
      line.kcal += e.nutrient(NutrientId.calories);
      line.protein += e.nutrient(NutrientId.protein);
      line.carbs += e.nutrient(NutrientId.carbohydrates);
      line.fat += e.nutrient(NutrientId.fat);
    }
    final lines = merged.values.toList();

    final rows = StringBuffer();
    for (final l in lines.take(_maxFoodRows)) {
      rows.write('<tr>'
          '<td class="food-name">${_esc(l.label)}'
          '${l.count > 1 ? ' <span class="muted">×${l.count}</span>' : ''}</td>'
          '<td class="r dt">${_esc(formatNutrientAmount(l.amount))} ${_esc(l.unit)}</td>'
          '<td class="r">${l.kcal.round()}</td>'
          '<td class="r">${_fmtNum(l.protein)}</td>'
          '<td class="r">${_fmtNum(l.carbs)}</td>'
          '<td class="r">${_fmtNum(l.fat)}</td>'
          '</tr>');
    }
    if (lines.length > _maxFoodRows) {
      final rest = lines.skip(_maxFoodRows);
      rows.write('<tr><td class="muted" colspan="2">'
          '+ ${rest.length} outros itens</td>'
          '<td class="r muted">${rest.fold(0.0, (s, l) => s + l.kcal).round()}</td>'
          '<td colspan="3"></td></tr>');
    }

    return '''
<table class="dt food-table">
  <thead><tr>
    <th>Alimento</th>
    <th class="r">Qtd.</th>
    <th class="r">kcal</th>
    <th class="r">P</th>
    <th class="r">C</th>
    <th class="r">G</th>
  </tr></thead>
  <tbody>$rows</tbody>
</table>''';
  }

  static String _summaryRow(_Day d) => '<tr>'
      '<td class="dt">${_esc(_weekdays[d.day.weekday - 1].substring(0, 3))} '
      '${_esc(_fmtDate(d.day))}</td>'
      '<td class="r big-val">${d.get(NutrientId.calories).round()}</td>'
      '<td class="r">${_fmtNum(d.get(NutrientId.protein))}</td>'
      '<td class="r">${_fmtNum(d.get(NutrientId.carbohydrates))}</td>'
      '<td class="r">${_fmtNum(d.get(NutrientId.fat))}</td>'
      '<td class="r">${_fmtNum(d.get(NutrientId.fiber))}</td>'
      '<td class="r">${d.get(NutrientId.sodium).round()}</td>'
      '<td class="r muted">${d.entries.length}</td>'
      '</tr>';

  static String _summaryTable(String rows) => '''
<table class="dt summary-table">
  <thead><tr>
    <th>Dia</th>
    <th class="r">kcal</th>
    <th class="r">Proteínas (g)</th>
    <th class="r">Carboidratos (g)</th>
    <th class="r">Gorduras (g)</th>
    <th class="r">Fibras (g)</th>
    <th class="r">Sódio (mg)</th>
    <th class="r">Registros</th>
  </tr></thead>
  <tbody>$rows</tbody>
</table>''';

  /// Every nutrient group with something to show, as bar rows packed
  /// into page columns of [_rowsPerColumn]. A group that doesn't fit the
  /// rest of a column continues in the next one under a "(cont.)" title,
  /// unless only a sliver of space is left - then it just starts fresh.
  static List<String> _panelColumns(
    _Day d,
    Map<NutrientId, Nutrient> catalog,
    double? Function(NutrientId) target,
  ) {
    // Same visibility rule as the Nutrição screen: anything eaten, plus
    // anything the active set explicitly targets. FDA fallbacks alone
    // don't make an untracked vitamin show up at zero.
    final byCategory = <NutrientCategory, List<Nutrient>>{};
    for (final n in catalog.values) {
      if (_skipInPanels.contains(n.id)) continue;
      if (d.get(n.id) <= 0 && target(n.id) == null) continue;
      byCategory.putIfAbsent(n.category, () => []).add(n);
    }
    for (final list in byCategory.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    final categories = byCategory.keys.toList()
      ..sort((a, b) => byCategory[a]!.first.sortOrder
          .compareTo(byCategory[b]!.first.sortOrder));

    final columns = <String>[];
    var col = StringBuffer();
    var used = 0;
    void nextColumn() {
      columns.add(col.toString());
      col = StringBuffer();
      used = 0;
    }

    for (final category in categories) {
      final nutrients = byCategory[category]!;
      // Rows without a target are scaled against the largest value of the
      // same unit in their group.
      final maxByUnit = <NutrientUnit, double>{};
      for (final n in nutrients) {
        if (target(n.id) != null) continue;
        maxByUnit[n.unit] = math.max(maxByUnit[n.unit] ?? 0, d.get(n.id));
      }
      final rows = [
        for (final n in nutrients) _nutrientRow(n, d.get(n.id), target(n.id),
            maxByUnit[n.unit] ?? 0)
      ];
      final label = kNutrientCategoryLabels[category] ?? category.name;

      var start = 0;
      while (start < rows.length) {
        if (_rowsPerColumn - used < _titleRows + 3) nextColumn();
        final room = _rowsPerColumn - used - _titleRows;
        final take = math.min(room, rows.length - start);
        col.write('<div class="panel">'
            '<h3 class="section-title">${_esc(label)}'
            '${start > 0 ? ' <span class="muted">(cont.)</span>' : ''}</h3>'
            '${rows.skip(start).take(take).join()}</div>');
        used += _titleRows + take;
        start += take;
      }
    }
    if (used > 0) nextColumn();
    return columns;
  }

  static String _nutrientRow(
      Nutrient n, double value, double? target, double unitMax) {
    final String color;
    final double width;
    final String pctText;
    if (target != null) {
      final ratio = value / target;
      final isCeiling = kCeilingNutrients.contains(n.id);
      color = isCeiling
          ? (ratio > 1 ? _overColor : _metColor)
          : ratio > 2
              ? _highColor
              : ratio >= 1
                  ? _metColor
                  : _partialColor;
      width = math.min(ratio, 1.0) * 100;
      pctText = '${(ratio * 100).round()}%';
    } else {
      color = _grey;
      width = unitMax > 0 ? value / unitMax * 100 : 0;
      pctText = '—';
    }
    final targetTitle = target == null
        ? ''
        : ' title="Meta: ${_esc(formatNutrientAmount(target))} ${_esc(n.unitLabel)}"';
    return '<div class="nr"$targetTitle>'
        '<span class="nr-name">${_esc(n.name)}</span>'
        '<span class="nr-val">${_esc(formatNutrientAmount(value))} '
        '<small>${_esc(n.unitLabel)}</small></span>'
        '<span class="nr-bar"><span style="width:${width.toStringAsFixed(1)}%;'
        'background:$color"></span></span>'
        '<span class="nr-pct">$pctText</span>'
        '</div>';
  }

  // ── Helpers ───────────────────────────────────────────────────────
  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _fmtDate(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year}';

  static String _fmtDayMonth(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

  /// Whole numbers from 100 up, one decimal below - for grams on cards
  /// and tables, where formatNutrientAmount's trace precision is noise.
  static String _fmtNum(double v) =>
      v.abs() >= 100 ? v.round().toString() : v.toStringAsFixed(1);

  static String _pageHeader(String title, String pageNum,
      [String subtitle = '']) {
    final sub = subtitle.isNotEmpty
        ? '<span class="hdr-sub">${_esc(subtitle)}</span>'
        : '';
    return '''<div class="hdr">
  <h2>${_esc(title)}</h2>
  $sub
  <span class="hdr-page">${_esc(pageNum)}</span>
</div>''';
  }

  static String _pageFooter(String period, String generatedAt) =>
      '''<div class="ftr">
  <span class="ftr-label">Relatório de Nutrição — ${_esc(period)}</span>
  <span class="ftr-date">Gerado em ${_esc(generatedAt)}</span>
</div>''';

  static String _css() => '''
/* Keep bar fills and ruled lines when printing. */
* { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
.svg-chart { flex-shrink: 0; }
.svg-chart svg { display: block; }
.chart-legend { justify-content: center; }
.panel-key i.dash {
  background: none;
  border-top: 2px dashed $_navy;
  height: 0;
}
.print-btn { display: none; }
body.in-browser .print-btn {
  display: block;
  position: fixed;
  top: 16px; right: 16px;
  z-index: 10;
  padding: 10px 18px;
  border: none;
  border-radius: 8px;
  background: $_navy;
  color: #fff;
  font: 600 10pt 'Segoe UI', Roboto, Arial, sans-serif;
  box-shadow: 0 2px 8px rgba(0,0,0,.25);
  cursor: pointer;
}
@media print { .print-btn { display: none !important; } }
.small { font-size: 8pt; }
.kpi-value small { font-size: 8pt; font-weight: 600; color: $_muted; }
.kpi-bar {
  height: 1.5mm;
  background: #e2e8f0;
  border-radius: 1mm;
  overflow: hidden;
  margin-top: 2mm;
}
.kpi-bar div { height: 100%; border-radius: 1mm; }

/* Day overview */
.day-grid {
  display: grid;
  grid-template-columns: 1.55fr 1fr;
  gap: 6mm;
  flex-shrink: 0;
  max-height: 120mm;
  overflow: hidden;
}
.day-foods, .day-split { display: flex; flex-direction: column; gap: 2mm; }
.food-table td, .food-table th { padding: 1.2mm 1.5mm; }
.food-name { max-width: 58mm; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.split-legend { display: flex; flex-direction: column; gap: 1.5mm; margin-top: 2mm; }
.split-row { display: flex; align-items: center; font-size: 8pt; }
.split-name { flex: 1; }
.split-val { color: $_muted; font-feature-settings: "tnum"; }

/* Notes: ruled lines to write on after printing */
.notes { flex: 1; display: flex; flex-direction: column; gap: 2mm; min-height: 40mm; }
.notes-lines {
  flex: 1;
  border: 1px solid #e2e8f0;
  border-radius: 2mm;
  background-image: linear-gradient(
    to bottom, transparent calc(100% - 1px), #dbe2ea calc(100% - 1px));
  background-size: 100% 8mm;
}

/* Nutrient panels */
.panel-cols {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8mm;
  flex: 1;
  overflow: hidden;
}
.panel-col { display: flex; flex-direction: column; gap: 3mm; min-width: 0; }
.panel .section-title { margin-bottom: 1mm; }
.nr {
  display: grid;
  grid-template-columns: 1fr 19mm 22mm 10mm;
  align-items: center;
  gap: 2mm;
  height: 4.8mm;
  font-size: 7.5pt;
  border-bottom: 1px solid #f1f5f9;
}
.nr-name { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.nr-val { text-align: right; font-feature-settings: "tnum"; white-space: nowrap; }
.nr-val small { color: $_muted; font-size: 6.5pt; }
.nr-bar { height: 2.6mm; background: #f1f5f9; border-radius: 1mm; overflow: hidden; display: block; }
.nr-bar span { display: block; height: 100%; border-radius: 1mm; }
.nr-pct { text-align: right; color: $_muted; font-feature-settings: "tnum"; }
.panel-key {
  display: flex;
  flex-wrap: wrap;
  gap: 1.5mm 5mm;
  font-size: 7pt;
  color: $_muted;
  flex-shrink: 0;
}
.panel-key i {
  display: inline-block;
  width: 3mm; height: 2.2mm;
  border-radius: 0.6mm;
  margin-right: 1.2mm;
  vertical-align: middle;
}
''';
}

/// One report day: its entries (oldest first) and nutrient totals.
class _Day {
  final DateTime day;
  final List<FoodEntry> entries;
  final Map<NutrientId, double> totals;

  _Day(this.day, this.entries) : totals = calculateTotals(entries);

  factory _Day.from(DateTime day, Iterable<FoodEntry> entries) {
    final sorted = entries.toList()
      ..sort((a, b) => (a.createdAt ?? DateTime(0))
          .compareTo(b.createdAt ?? DateTime(0)));
    return _Day(day, sorted);
  }

  double get(NutrientId id) => totals[id] ?? 0;
}

class _FoodLine {
  final String label;
  final String unit;
  double amount = 0;
  int count = 0;
  double kcal = 0;
  double protein = 0;
  double carbs = 0;
  double fat = 0;

  _FoodLine(this.label, this.unit);
}
