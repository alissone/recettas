import 'dart:collection';
import 'dart:convert';

import '../models/purchase.dart';
import '../models/purchase_category.dart';
import '../utils/brl.dart';

/// Builds the monthly purchases report as a self-contained HTML document:
/// A4-styled pages with Chart.js charts, meant to be shown in a WebView
/// (and, later, printed). Ported from the desktop generator
/// (Projetos/Gastos/generate.py), minus the food/restock pages, which
/// need spreadsheet columns the app doesn't record.
class ReportGenerator {
  ReportGenerator._();

  // Palette (same as the desktop report).
  static const _navy = '#1a2744';
  static const _gold = '#c9a84c';
  static const _text = '#1e2a3a';
  static const _muted = '#6b7a8d';
  static const _lightBg = '#f1f5f9';
  static const _grey = '#94a3b8';

  static const _palette = [
    '#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6',
    '#06b6d4', '#f97316', '#84cc16', '#ec4899', '#6366f1',
    '#14b8a6', '#a855f7', '#fb923c', '#22c55e', '#e11d48',
    '#0ea5e9', '#d97706', '#16a34a', '#7c3aed', '#db2777',
  ];

  static const _monthNames = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  static const _tableRowsPerPage = 30;

  /// [purchases] must not be empty.
  static String buildMonthlyReport({
    required DateTime month,
    required List<Purchase> purchases,
    required List<PurchaseCategory> categories,
    required String chartJs,
  }) {
    final reportMonth = '${_monthNames[month.month - 1]} ${month.year}';
    final now = DateTime.now();
    final nowStr = '${_two(now.day)}/${_two(now.month)}/${now.year} '
        '${_two(now.hour)}:${_two(now.minute)}';

    final txns = [...purchases]
      ..sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));

    final catById = {for (final c in categories) c.id: c};
    String catName(Purchase t) =>
        catById[t.categoryId]?.name ?? 'Sem categoria';
    final catColorByName = {
      'Sem categoria': _grey,
      for (final c in categories) c.name: _hex(c.colorValue),
    };

    // ── Aggregations ────────────────────────────────────────────────
    final total = txns.fold(0.0, (s, t) => s + t.valor);
    final startDate = _fmtDate(txns.first.purchaseDate);
    final endDate = _fmtDate(txns.last.purchaseDate);

    final daily = SplayTreeMap<String, double>();
    for (final t in txns) {
      daily[t.purchaseDate] = (daily[t.purchaseDate] ?? 0) + t.valor;
    }
    final dayKeys = daily.keys.toList();
    final dailyLabels = [
      for (final d in dayKeys) '${d.substring(8, 10)}/${d.substring(5, 7)}'
    ];
    final dailyValues = [for (final d in dayKeys) _r2(daily[d]!)];
    final avgDaily = total / daily.length;

    var maxDay = 0.0;
    var maxDayLabel = '';
    for (var i = 0; i < dayKeys.length; i++) {
      if (dailyValues[i] > maxDay) {
        maxDay = dailyValues[i];
        maxDayLabel = dailyLabels[i];
      }
    }

    final cumulative = <double>[];
    var acc = 0.0;
    for (final d in dayKeys) {
      acc += daily[d]!;
      cumulative.add(_r2(acc));
    }

    // Stores (top 15 + "Outros").
    final stores = <String, double>{};
    for (final t in txns) {
      final s = t.local?.trim();
      final key = (s == null || s.isEmpty) ? '—' : s;
      stores[key] = (stores[key] ?? 0) + t.valor;
    }
    final storesSorted = stores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final storeLabels = [for (final e in storesSorted.take(15)) e.key];
    final storeValues = [
      for (final e in storesSorted.take(15)) _r2(e.value)
    ];
    final otherStores =
        storesSorted.skip(15).fold(0.0, (s, e) => s + e.value);
    if (otherStores > 0) {
      storeLabels.add('Outros');
      storeValues.add(_r2(otherStores));
    }

    // Categories, largest first.
    final catTotals = <String, double>{};
    for (final t in txns) {
      final n = catName(t);
      catTotals[n] = (catTotals[n] ?? 0) + t.valor;
    }
    final catsSorted = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final catLabels = [for (final e in catsSorted) e.key];
    final catValues = [for (final e in catsSorted) _r2(e.value)];
    final catColors = [
      for (final e in catsSorted) catColorByName[e.key] ?? _grey
    ];

    final top20 = ([...txns]..sort((a, b) => b.valor.compareTo(a.valor)))
        .take(20)
        .toList();

    // ── Table fragments ─────────────────────────────────────────────
    final catRows = StringBuffer();
    for (var i = 0; i < catLabels.length; i++) {
      final pct = total > 0 ? catValues[i] / total * 100 : 0.0;
      catRows.write('<tr>'
          '<td><span class="dot" style="background:${catColors[i]}"></span>'
          '${_esc(catLabels[i])}</td>'
          '<td class="r brl">${_esc(formatBrl(catValues[i]))}</td>'
          '<td class="r">${pct.toStringAsFixed(1)}%</td>'
          '</tr>');
    }

    final storeTotal = storeValues.fold(0.0, (s, v) => s + v);
    final storeRows = StringBuffer();
    for (var i = 0; i < storeLabels.length; i++) {
      final pct = storeTotal > 0 ? storeValues[i] / storeTotal * 100 : 0.0;
      final width = pct > 100 ? 100.0 : pct;
      storeRows.write('<tr>'
          '<td>${_esc(storeLabels[i])}</td>'
          '<td class="r brl">${_esc(formatBrl(storeValues[i]))}</td>'
          '<td class="r">${pct.toStringAsFixed(1)}%</td>'
          '<td><div class="bar-cell"><div class="bar-fill" '
          'style="width:${width.toStringAsFixed(1)}%"></div></div></td>'
          '</tr>');
    }

    final topRows = StringBuffer();
    for (var rank = 0; rank < top20.length; rank++) {
      final t = top20[rank];
      final color = catColorByName[catName(t)] ?? _grey;
      topRows.write('<tr>'
          '<td class="r muted">${rank + 1}</td>'
          '<td>${_esc(t.item)}</td>'
          '<td class="r brl big-val">${_esc(formatBrl(t.valor))}</td>'
          '<td>${_esc(t.local ?? '—')}</td>'
          '<td class="dt">${_esc(_fmtDate(t.purchaseDate))}</td>'
          '<td>${_catBadge(catName(t), color)}</td>'
          '</tr>');
    }

    // Full transaction table, category-major (largest category first,
    // matching the summary), then store, then date. 30 rows per page.
    final catRank = {
      for (var i = 0; i < catLabels.length; i++) catLabels[i]: i
    };
    final tableTxns = [...txns]..sort((a, b) {
        final byCat = (catRank[catName(a)] ?? 0)
            .compareTo(catRank[catName(b)] ?? 0);
        if (byCat != 0) return byCat;
        final byStore = (a.local ?? '')
            .toLowerCase()
            .compareTo((b.local ?? '').toLowerCase());
        if (byStore != 0) return byStore;
        return a.purchaseDate.compareTo(b.purchaseDate);
      });

    final tablePages = <String>[];
    for (var i = 0; i < tableTxns.length; i += _tableRowsPerPage) {
      final rows = StringBuffer();
      for (final t in tableTxns.skip(i).take(_tableRowsPerPage)) {
        final color = catColorByName[catName(t)] ?? _grey;
        rows.write('<tr>'
            '<td class="dt">${_esc(_fmtDate(t.purchaseDate))}</td>'
            '<td>${_esc(t.item)}</td>'
            '<td class="r brl">${_esc(formatBrl(t.valor))}</td>'
            '<td>${_esc(t.local ?? '—')}</td>'
            '<td>${_catBadge(catName(t), color)}</td>'
            '</tr>');
      }
      tablePages.add(rows.toString());
    }

    const tableFirstPage = 8;
    final tableHtml = StringBuffer();
    for (var i = 0; i < tablePages.length; i++) {
      tableHtml.write('''
<div class="page page-table">
  ${_pageHeader('Tabela Completa de Compras', '${tableFirstPage + i}', 'Página ${i + 1} de ${tablePages.length}')}
  <div class="body">
    <table class="dt">
      <thead><tr>
        <th class="dt">Data</th>
        <th>Item</th>
        <th class="r">Valor</th>
        <th>Local</th>
        <th>Categoria</th>
      </tr></thead>
      <tbody>${tablePages[i]}</tbody>
    </table>
  </div>
  ${_pageFooter(reportMonth, nowStr)}
</div>''');
    }

    // ── Document ────────────────────────────────────────────────────
    final j = jsonEncode;

    return '''<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=794">
<style>
${_css()}
</style>
</head>
<body>

<!-- PÁGINA 1 — CAPA -->
<div class="page page-cover">
  <div class="cover-bg-shape"></div>
  <div class="cover-content">
    <div class="cover-eyebrow">RELATÓRIO FINANCEIRO</div>
    <div class="cover-rule"></div>
    <h1 class="cover-title">Gastos<br>${_esc(reportMonth)}</h1>
    <div class="cover-rule"></div>
    <div class="cover-kpis">
      <div class="cover-kpi">
        <div class="cover-kpi-val">${_esc(formatBrl(total))}</div>
        <div class="cover-kpi-lbl">Total Gasto</div>
      </div>
      <div class="cover-kpi-sep"></div>
      <div class="cover-kpi">
        <div class="cover-kpi-val">${txns.length}</div>
        <div class="cover-kpi-lbl">Compras</div>
      </div>
      <div class="cover-kpi-sep"></div>
      <div class="cover-kpi">
        <div class="cover-kpi-val">${_esc(formatBrl(avgDaily))}</div>
        <div class="cover-kpi-lbl">Média Diária</div>
      </div>
    </div>
    <div class="cover-period">${_esc(startDate)} — ${_esc(endDate)}</div>
  </div>
  <div class="cover-footer">Gerado em ${_esc(nowStr)}</div>
</div>

<!-- PÁGINA 2 — RESUMO EXECUTIVO -->
<div class="page page-content">
  ${_pageHeader('Resumo Executivo', '2')}
  <div class="body">
    <div class="kpi-grid">
      <div class="kpi-card" style="border-top:3px solid $_gold">
        <div class="kpi-label">Total Gasto</div>
        <div class="kpi-value" style="color:$_navy">${_esc(formatBrl(total))}</div>
        <div class="kpi-sub">Período: ${_esc(startDate)} a ${_esc(endDate)}</div>
      </div>
      <div class="kpi-card" style="border-top:3px solid #10b981">
        <div class="kpi-label">Total de Compras</div>
        <div class="kpi-value" style="color:#10b981">${txns.length}</div>
        <div class="kpi-sub">Em ${dayKeys.length} dias</div>
      </div>
      <div class="kpi-card" style="border-top:3px solid #3b82f6">
        <div class="kpi-label">Média por Dia</div>
        <div class="kpi-value" style="color:#3b82f6">${_esc(formatBrl(avgDaily))}</div>
        <div class="kpi-sub">${dayKeys.length} dias com gastos</div>
      </div>
      <div class="kpi-card" style="border-top:3px solid #ef4444">
        <div class="kpi-label">Maior Dia</div>
        <div class="kpi-value" style="color:#ef4444">${_esc(formatBrl(maxDay))}</div>
        <div class="kpi-sub">${_esc(maxDayLabel)}</div>
      </div>
    </div>
    <h3 class="section-title">Gastos por Categoria — Visão Geral</h3>
    <table class="dt summary-table">
      <thead><tr>
        <th>Categoria</th>
        <th class="r">Total</th>
        <th class="r">% do Total</th>
      </tr></thead>
      <tbody>$catRows</tbody>
    </table>
  </div>
  ${_pageFooter(reportMonth, nowStr)}
</div>

<!-- PÁGINA 3 — ANÁLISE TEMPORAL -->
<div class="page page-content">
  ${_pageHeader('Análise Temporal', '3')}
  <div class="body">
    <h3 class="section-title">Gastos Diários (R\$)</h3>
    <div class="chart-wrap" style="height:195mm">
      <canvas id="chartDaily"></canvas>
    </div>
  </div>
  ${_pageFooter(reportMonth, nowStr)}
</div>

<!-- PÁGINA 4 — ACUMULADO -->
<div class="page page-content">
  ${_pageHeader('Gasto Acumulado no Mês', '4')}
  <div class="body">
    <h3 class="section-title">Evolução do Gasto Acumulado (R\$)</h3>
    <div class="chart-wrap" style="height:195mm">
      <canvas id="chartCumulative"></canvas>
    </div>
  </div>
  ${_pageFooter(reportMonth, nowStr)}
</div>

<!-- PÁGINA 5 — LOCAIS -->
<div class="page page-content">
  ${_pageHeader('Gastos por Local', '5')}
  <div class="body">
    <div class="two-col" style="gap:8mm">
      <div>
        <h3 class="section-title">Top Locais</h3>
        <div class="chart-wrap" style="height:180mm">
          <canvas id="chartStores"></canvas>
        </div>
      </div>
      <div>
        <h3 class="section-title">Detalhamento</h3>
        <table class="dt store-table">
          <thead><tr>
            <th>Local</th>
            <th class="r">Total</th>
            <th class="r">%</th>
            <th style="min-width:40mm">Barra</th>
          </tr></thead>
          <tbody>$storeRows</tbody>
        </table>
      </div>
    </div>
  </div>
  ${_pageFooter(reportMonth, nowStr)}
</div>

<!-- PÁGINA 6 — CATEGORIAS -->
<div class="page page-content">
  ${_pageHeader('Distribuição por Categoria', '6')}
  <div class="body">
    <div class="two-col" style="gap:8mm">
      <div>
        <h3 class="section-title">Distribuição (%)</h3>
        <div class="chart-wrap" style="height:180mm">
          <canvas id="chartCatPie"></canvas>
        </div>
      </div>
      <div>
        <h3 class="section-title">Total por Categoria (R\$)</h3>
        <div class="chart-wrap" style="height:180mm">
          <canvas id="chartCatBar"></canvas>
        </div>
      </div>
    </div>
  </div>
  ${_pageFooter(reportMonth, nowStr)}
</div>

<!-- PÁGINA 7 — MAIORES GASTOS -->
<div class="page page-content">
  ${_pageHeader('Top 20 Maiores Gastos', '7')}
  <div class="body">
    <table class="dt top-table">
      <thead><tr>
        <th class="r">#</th>
        <th>Item</th>
        <th class="r">Valor</th>
        <th>Local</th>
        <th class="dt">Data</th>
        <th>Categoria</th>
      </tr></thead>
      <tbody>$topRows</tbody>
    </table>
  </div>
  ${_pageFooter(reportMonth, nowStr)}
</div>

$tableHtml

<script>
$chartJs

const brl = v => 'R\$ ' + v.toLocaleString('pt-BR', {minimumFractionDigits: 2});
const brlAxis = v => 'R\$ ' + v.toLocaleString('pt-BR');

new Chart(document.getElementById('chartDaily'), {
  type: 'bar',
  data: {
    labels: ${j(dailyLabels)},
    datasets: [{
      label: 'Gasto Diário (R\$)',
      data: ${j(dailyValues)},
      backgroundColor: '${_gold}cc',
      borderColor: '$_gold',
      borderWidth: 1,
      borderRadius: 3,
    }]
  },
  options: {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      tooltip: { callbacks: { label: ctx => brl(ctx.parsed.y) } }
    },
    scales: {
      y: { beginAtZero: true, ticks: { callback: brlAxis } },
      x: { ticks: { maxRotation: 45, minRotation: 45, font: { size: 9 } } }
    }
  }
});

new Chart(document.getElementById('chartCumulative'), {
  type: 'line',
  data: {
    labels: ${j(dailyLabels)},
    datasets: [{
      label: 'Acumulado (R\$)',
      data: ${j(cumulative)},
      borderColor: '$_navy',
      backgroundColor: '${_navy}22',
      fill: true,
      tension: 0.3,
      pointRadius: 3,
      pointBackgroundColor: '$_gold',
    }]
  },
  options: {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      tooltip: { callbacks: { label: ctx => brl(ctx.parsed.y) } }
    },
    scales: {
      y: { beginAtZero: true, ticks: { callback: brlAxis } },
      x: { ticks: { maxRotation: 45, minRotation: 45, font: { size: 9 } } }
    }
  }
});

new Chart(document.getElementById('chartStores'), {
  type: 'bar',
  data: {
    labels: ${j(storeLabels)},
    datasets: [{
      label: 'Total (R\$)',
      data: ${j(storeValues)},
      backgroundColor: ${j(_paletteN(storeValues.length))},
      borderRadius: 3,
    }]
  },
  options: {
    indexAxis: 'y',
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      tooltip: { callbacks: { label: ctx => brl(ctx.parsed.x) } }
    },
    scales: {
      x: { beginAtZero: true, ticks: { callback: brlAxis, font: { size: 9 } } },
      y: { ticks: { font: { size: 9 } } }
    }
  }
});

new Chart(document.getElementById('chartCatPie'), {
  type: 'doughnut',
  data: {
    labels: ${j(catLabels)},
    datasets: [{
      data: ${j(catValues)},
      backgroundColor: ${j(catColors)},
      borderWidth: 2,
      borderColor: '#fff',
    }]
  },
  options: {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { position: 'bottom', labels: { font: { size: 9 }, padding: 8 } },
      tooltip: { callbacks: { label: ctx => ctx.label + ': ' + brl(ctx.parsed) } }
    }
  }
});

new Chart(document.getElementById('chartCatBar'), {
  type: 'bar',
  data: {
    labels: ${j(catLabels)},
    datasets: [{
      label: 'Total (R\$)',
      data: ${j(catValues)},
      backgroundColor: ${j(catColors)},
      borderRadius: 3,
    }]
  },
  options: {
    indexAxis: 'y',
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      tooltip: { callbacks: { label: ctx => brl(ctx.parsed.x) } }
    },
    scales: {
      x: { beginAtZero: true, ticks: { callback: brlAxis, font: { size: 9 } } },
      y: { ticks: { font: { size: 9 } } }
    }
  }
});

window.__chartsReady = true;
</script>
</body>
</html>''';
  }

  // ── Helpers ───────────────────────────────────────────────────────
  static String _two(int n) => n.toString().padLeft(2, '0');

  static double _r2(double v) => (v * 100).roundToDouble() / 100;

  static String _hex(int colorValue) =>
      '#${(colorValue & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// "YYYY-MM-DD" → "DD/MM/YYYY".
  static String _fmtDate(String iso) => iso.length >= 10
      ? '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}'
      : iso;

  static String _esc(Object? v) => v == null
      ? ''
      : v
          .toString()
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;')
          .replaceAll("'", '&#39;');

  static List<String> _paletteN(int n) =>
      [for (var i = 0; i < n; i++) _palette[i % _palette.length]];

  static String _catBadge(String name, String color) =>
      '<span class="cat-badge" style="background:${color}20;color:$color">'
      '${_esc(name)}</span>';

  static String _pageHeader(String title, String pageNum,
      [String subtitle = '']) {
    final sub =
        subtitle.isNotEmpty ? '<span class="hdr-sub">${_esc(subtitle)}</span>' : '';
    return '''<div class="hdr">
  <h2>${_esc(title)}</h2>
  $sub
  <span class="hdr-page">${_esc(pageNum)}</span>
</div>''';
  }

  static String _pageFooter(String month, String generatedAt) =>
      '''<div class="ftr">
  <span class="ftr-label">Relatório de Gastos — ${_esc(month)}</span>
  <span class="ftr-date">Gerado em ${_esc(generatedAt)}</span>
</div>''';

  static String _css() => '''
/* Reset & base */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
@page { size: A4; margin: 0; }
body {
  font-family: 'Segoe UI', Roboto, Arial, sans-serif;
  font-size: 10pt;
  color: $_text;
  background: #ccc;
}

/* Page shell */
.page {
  width: 210mm;
  height: 297mm;
  overflow: hidden;
  page-break-after: always;
  display: flex;
  flex-direction: column;
  position: relative;
  background: white;
}
@media screen {
  body { padding: 12px 0; }
  .page { margin: 0 auto 12px; }
}

/* Shared header */
.hdr {
  background: $_navy;
  height: 14mm;
  padding: 0 12mm;
  display: flex;
  align-items: center;
  gap: 8mm;
  border-bottom: 2px solid $_gold;
  flex-shrink: 0;
}
.hdr h2 {
  color: #fff;
  font-size: 14pt;
  font-weight: 600;
  flex: 1;
  letter-spacing: 0.3px;
}
.hdr-sub { color: $_gold; font-size: 8pt; letter-spacing: 1px; }
.hdr-page {
  color: rgba(255,255,255,.4);
  font-size: 9pt;
  min-width: 6mm;
  text-align: right;
}

/* Body */
.body {
  flex: 1;
  padding: 6mm 12mm 4mm;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  gap: 4mm;
}

/* Footer */
.ftr {
  height: 8mm;
  padding: 0 12mm;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-top: 1px solid #e2e8f0;
  flex-shrink: 0;
}
.ftr-label, .ftr-date { color: $_muted; font-size: 8pt; }

/* Cover page */
.page-cover {
  background: $_navy;
  align-items: center;
  justify-content: center;
  text-align: center;
  flex-direction: column;
  gap: 0;
}
.cover-bg-shape {
  position: absolute;
  bottom: 0; right: 0;
  width: 0; height: 0;
  border-bottom: 100mm solid rgba(201,168,76,.08);
  border-left: 100mm solid transparent;
}
.cover-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8mm;
  position: relative;
  z-index: 1;
  padding: 0 20mm;
  max-width: 180mm;
}
.cover-eyebrow {
  color: $_gold;
  font-size: 9pt;
  letter-spacing: 4px;
  text-transform: uppercase;
  opacity: .85;
}
.cover-rule { width: 20mm; height: 2px; background: $_gold; }
.cover-title {
  color: #fff;
  font-size: 34pt;
  font-weight: 700;
  line-height: 1.2;
  text-align: center;
}
.cover-kpis {
  display: flex;
  align-items: center;
  gap: 8mm;
  margin-top: 4mm;
}
.cover-kpi { text-align: center; }
.cover-kpi-val { color: $_gold; font-size: 16pt; font-weight: 700; }
.cover-kpi-lbl {
  color: rgba(255,255,255,.6);
  font-size: 8pt;
  letter-spacing: 1px;
  margin-top: 2mm;
}
.cover-kpi-sep { width: 1px; height: 12mm; background: rgba(255,255,255,.15); }
.cover-period {
  color: rgba(255,255,255,.4);
  font-size: 9pt;
  letter-spacing: .5px;
  margin-top: 2mm;
}
.cover-footer {
  position: absolute;
  bottom: 8mm;
  color: rgba(255,255,255,.2);
  font-size: 8pt;
}

/* KPI cards */
.kpi-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 4mm;
  flex-shrink: 0;
}
.kpi-card { background: $_lightBg; border-radius: 4mm; padding: 4mm; }
.kpi-label {
  font-size: 7.5pt;
  color: $_muted;
  text-transform: uppercase;
  letter-spacing: .5px;
  margin-bottom: 2mm;
}
.kpi-value { font-size: 14pt; font-weight: 700; line-height: 1; }
.kpi-sub { font-size: 7.5pt; color: $_muted; margin-top: 1.5mm; }

/* Section title */
.section-title {
  font-size: 9pt;
  font-weight: 600;
  color: $_navy;
  text-transform: uppercase;
  letter-spacing: 1px;
  padding-bottom: 2mm;
  border-bottom: 1px solid #e2e8f0;
  flex-shrink: 0;
}

/* Charts */
.chart-wrap { position: relative; flex: 1; }
.chart-wrap canvas {
  position: absolute;
  top: 0; left: 0;
  width: 100% !important;
  height: 100% !important;
}

/* Two-column */
.two-col {
  display: grid;
  grid-template-columns: 1fr 1fr;
  flex: 1;
  overflow: hidden;
}

/* Tables */
table.dt {
  width: 100%;
  border-collapse: collapse;
  font-size: 7.5pt;
}
table.dt th {
  background: $_lightBg;
  padding: 2mm 2.5mm;
  font-weight: 600;
  color: $_muted;
  border-bottom: 2px solid #e2e8f0;
  text-align: left;
  white-space: nowrap;
}
table.dt td {
  padding: 1.5mm 2.5mm;
  border-bottom: 1px solid #f1f5f9;
  vertical-align: middle;
}
table.dt tr:nth-child(even) td { background: #fafbfc; }
.r { text-align: right; }
.dt { white-space: nowrap; }
.muted { color: $_muted; }
.brl { font-feature-settings: "tnum"; white-space: nowrap; }
.big-val { font-weight: 600; color: $_navy; }

/* Category badge */
.cat-badge {
  display: inline-block;
  padding: 0.5mm 2mm;
  border-radius: 3mm;
  font-size: 7pt;
  font-weight: 600;
  white-space: nowrap;
}
.dot {
  display: inline-block;
  width: 2.5mm; height: 2.5mm;
  border-radius: 50%;
  margin-right: 1.5mm;
  vertical-align: middle;
  flex-shrink: 0;
}

/* Bar cell in table */
.bar-cell {
  height: 4mm;
  background: #f1f5f9;
  border-radius: 1mm;
  overflow: hidden;
}
.bar-fill { height: 100%; background: $_gold; border-radius: 1mm; }

/* Summary table in exec summary */
.summary-table { font-size: 8pt; }
.summary-table td, .summary-table th { padding: 2mm 3mm; }

/* Store table */
.store-table { font-size: 7pt; }
.store-table td, .store-table th { padding: 1mm 1.5mm; }

/* Top items table */
.top-table td, .top-table th { padding: 1.5mm 2mm; }

/* Table pages */
.page-table .body { padding-top: 4mm; }
''';
}
