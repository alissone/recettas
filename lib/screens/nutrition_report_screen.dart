import 'package:flutter/material.dart';
import 'dart:typed_data';

import '../app_theme.dart';
import '../models/energy_estimate.dart';
import '../models/food.dart';
import '../models/nutrient.dart';
import '../models/nutrient_daily_values.dart';
import '../services/nutrition_report_generator.dart';
import '../services/report_pdf.dart';
import '../services/supabase_service.dart';
import '../utils/dates.dart';
import '../widgets/food_log_calendar.dart';
import '../widgets/report_html_view.dart';

/// Printable nutrition report: pick the days on a month calendar of the
/// food log, then view the A4 report NutritionReportGenerator builds for
/// them. Days can be picked across several months.
class NutritionReportScreen extends StatefulWidget {
  const NutritionReportScreen({super.key});

  @override
  State<NutritionReportScreen> createState() => _NutritionReportScreenState();
}

class _NutritionReportScreenState extends State<NutritionReportScreen> {
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _error;

  Map<NutrientId, Nutrient> _catalog = {};
  Map<NutrientId, double> _targets = {};
  double? _goalCalories;

  /// First day of the visible month.
  late DateTime _month;

  /// Entries per loaded month ("YYYY-MM"), so paging back to a month -
  /// or generating a report spanning several - costs no new request.
  final Map<String, List<FoodEntry>> _entriesByMonth = {};

  /// Replaced, never mutated, so the calendar painter sees the change.
  Set<DateTime> _selected = {};
  int _loadSeq = 0;

  String _monthKey(DateTime d) => isoDate(d).substring(0, 7);

  bool get _isAtCurrentMonth {
    final now = today();
    return _month.year == now.year && _month.month == now.month;
  }

  /// Day -> kcal for the visible month; a key per day with any entry.
  Map<DateTime, double> get _kcalByDay {
    final result = <DateTime, double>{};
    for (final e in _entriesByMonth[_monthKey(_month)] ?? const []) {
      final day = DateTime.tryParse(e.entryDate);
      if (day == null) continue;
      final key = DateTime(day.year, day.month, day.day);
      result[key] = (result[key] ?? 0) + e.nutrient(NutrientId.calories);
    }
    return result;
  }

  double? get _kcalTarget => effectiveNutrientTarget(NutrientId.calories,
      targets: _targets, goalCalories: _goalCalories);

  @override
  void initState() {
    super.initState();
    final now = today();
    _month = DateTime(now.year, now.month, 1);
    _loadAll();
  }

  /// Catalog and targets - the same sources, and the same fallback to the
  /// first shared preset, as the Nutrição screen.
  Future<void> _loadAll() async {
    if (SupabaseService.currentUser == null) {
      setState(() {
        _isLoading = false;
        _error = 'Entre na sua conta para gerar relatórios.';
      });
      return;
    }
    try {
      final catalogList = await SupabaseService.getNutrientCatalog();
      final sets = await SupabaseService.getRecommendationSets();
      Map<String, dynamic>? profile;
      try {
        profile = await SupabaseService.getProfile();
      } catch (_) {
        // Profile row missing: run without the calorie estimate.
      }
      final setId = profile?['active_recommendation_set_id'] as String? ??
          sets.where((s) => s.isShared).firstOrNull?.id;
      final recommendations = setId == null
          ? const []
          : await SupabaseService.getRecommendations(setId);

      if (!mounted) return;
      _catalog = {for (final n in catalogList) n.id: n};
      _targets = {for (final r in recommendations) r.nutrient: r.amount};
      _goalCalories = EnergyEstimate.fromProfile(profile)?.goalCalories;
      await _loadMonth();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Falha ao carregar: $e';
        });
      }
    }
  }

  Future<void> _loadMonth() async {
    final key = _monthKey(_month);
    if (_entriesByMonth.containsKey(key)) {
      setState(() => _isLoading = false);
      return;
    }
    final seq = ++_loadSeq;
    setState(() => _isLoading = true);
    try {
      final entries = await SupabaseService.getFoodEntries(
        fromDate: isoDate(_month),
        toDateExclusive:
            isoDate(DateTime(_month.year, _month.month + 1, 1)),
        catalog: _catalog,
      );
      if (!mounted) return;
      _entriesByMonth[key] = entries;
      if (seq == _loadSeq) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted && seq == _loadSeq) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao carregar: $e')));
      }
    }
  }

  void _changeMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta, 1);
    final now = today();
    if (next.isAfter(DateTime(now.year, now.month, 1))) return;
    setState(() => _month = next);
    _loadMonth();
  }

  void _toggleDay(DateTime day) {
    setState(() {
      _selected = {..._selected};
      if (!_selected.remove(day)) _selected.add(day);
    });
  }

  /// Selects every logged day of the visible month, or clears them all
  /// when they already are.
  void _toggleMonth() {
    final logged = _kcalByDay.keys.toSet();
    setState(() {
      _selected = logged.every(_selected.contains)
          ? _selected.difference(logged)
          : _selected.union(logged);
    });
  }

  Future<void> _generate() async {
    if (_selected.isEmpty) return;
    setState(() => _isGenerating = true);
    try {
      final days = _selected.toList()..sort();
      final wanted = {for (final d in days) isoDate(d)};
      final entries = [
        for (final list in _entriesByMonth.values)
          ...list.where((e) => wanted.contains(e.entryDate)),
      ];
      final html = NutritionReportGenerator.buildReport(
        days: days,
        entries: entries,
        catalog: _catalog,
        targets: _targets,
        goalCalories: _goalCalories,
      );
      if (!mounted) return;
      final fileName = days.length == 1
          ? 'nutricao_${isoDate(days.first)}'
          : 'nutricao_${isoDate(days.first)}_${isoDate(days.last)}';
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ReportViewerPage(
            title: days.length == 1
                ? 'Nutrição — ${formatDayMonth(days.first)}'
                : 'Nutrição — ${days.length} dias',
            html: html,
            fileName: fileName,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao gerar relatório: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.creamBackground,
        foregroundColor: AppTheme.darkBrown,
        elevation: 0,
        title: const Text('Relatório de nutrição',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              onPressed: () => setState(() => _selected = {}),
              icon: const Icon(Icons.deselect),
              tooltip: 'Limpar seleção',
            ),
        ],
      ),
      body: SafeArea(
        child: _error != null
            ? _buildMessage(Icons.error_outline, _error!)
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildCalendarCard(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _selected.isEmpty || _isGenerating
                          ? null
                          : _generate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.description_outlined),
                      label: Text(_selected.isEmpty
                          ? 'Selecione os dias'
                          : _selected.length == 1
                              ? 'Gerar relatório (1 dia)'
                              : 'Gerar relatório (${_selected.length} dias)'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    final kcalByDay = _kcalByDay;
    final selectedHere = _selected
        .where((d) => d.year == _month.year && d.month == _month.month)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
                color: AppTheme.mediumBrown,
                visualDensity: VisualDensity.compact,
                tooltip: 'Mês anterior',
              ),
              Expanded(
                child: Center(
                  child: Text(formatMonthYear(_month),
                      style: AppTheme.caption
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
              ),
              IconButton(
                onPressed:
                    _isAtCurrentMonth ? null : () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right),
                color: AppTheme.mediumBrown,
                visualDensity: VisualDensity.compact,
                tooltip: 'Próximo mês',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoading)
            const SizedBox(
              height: 260,
              child: Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primaryOrange),
              ),
            )
          else
            FoodLogCalendar(
              month: _month,
              kcalByDay: kcalByDay,
              kcalTarget: _kcalTarget,
              selected: _selected,
              onDayTap: _toggleDay,
            ),
          const SizedBox(height: 14),
          const FoodLogCalendarLegend(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  kcalByDay.isEmpty
                      ? 'Nenhum alimento registrado neste mês.'
                      : '${kcalByDay.length} dias com registros · '
                          '$selectedHere selecionados',
                  style: AppTheme.caption
                      .copyWith(fontWeight: FontWeight.w400),
                ),
              ),
              if (!_isLoading && kcalByDay.isNotEmpty)
                TextButton(
                  onPressed: _toggleMonth,
                  child: Text(
                    selectedHere == kcalByDay.length
                        ? 'Limpar mês'
                        : 'Selecionar mês',
                    style:
                        const TextStyle(color: AppTheme.primaryOrange),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Toque nos dias para incluir ou remover do relatório.',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.mediumBrown),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center, style: AppTheme.bodyText),
          ],
        ),
      ),
    );
  }
}

/// The generated report, with print and save-as-PDF actions. The PDF is
/// converted once, on first use, and reused by both actions.
class _ReportViewerPage extends StatefulWidget {
  final String title;
  final String html;
  final String fileName;

  const _ReportViewerPage({
    required this.title,
    required this.html,
    required this.fileName,
  });

  @override
  State<_ReportViewerPage> createState() => _ReportViewerPageState();
}

class _ReportViewerPageState extends State<_ReportViewerPage> {
  Uint8List? _pdf;
  bool _isBusy = false;

  Future<void> _withPdf(Future<void> Function(Uint8List pdf) action) async {
    setState(() => _isBusy = true);
    try {
      _pdf ??= await ReportPdf.fromHtml(widget.html);
      await action(_pdf!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao gerar o PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _print() =>
      _withPdf((pdf) => ReportPdf.printPdf(pdf, widget.fileName));

  void _save() => _withPdf((pdf) async {
        final path = await ReportPdf.savePdf(pdf, widget.fileName);
        if (path != null && mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('PDF salvo em $path')));
        }
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.creamBackground,
        foregroundColor: AppTheme.darkBrown,
        elevation: 0,
        title: Text(widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isBusy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primaryOrange),
              ),
            )
          else ...[
            IconButton(
              onPressed: _print,
              icon: const Icon(Icons.print_outlined),
              tooltip: 'Imprimir',
            ),
            IconButton(
              onPressed: _save,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Salvar PDF',
            ),
          ],
        ],
      ),
      body: ReportHtmlView(html: widget.html, fileName: widget.fileName),
    );
  }
}
