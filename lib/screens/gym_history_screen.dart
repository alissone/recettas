import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/exercise_log.dart';
import '../models/gym_entry.dart';
import '../services/supabase_service.dart';
import '../utils/dates.dart';
import '../widgets/exercise_thumb.dart';
import 'gym_exercise_history_screen.dart';

/// Every exercise ever trained, one row each, with its record weight and
/// how often it comes up. Tapping one opens its charts and calendar.
class GymHistoryScreen extends StatefulWidget {
  const GymHistoryScreen({super.key});

  @override
  State<GymHistoryScreen> createState() => _GymHistoryScreenState();
}

/// How the exercise list is ordered.
enum _Sort { recent, frequent, heaviest }

const _kSortLabels = {
  _Sort.recent: 'Recentes',
  _Sort.frequent: 'Mais feitos',
  _Sort.heaviest: 'Maior peso',
};

class _GymHistoryScreenState extends State<GymHistoryScreen> {
  bool _isLoading = true;
  String? _error;

  List<ExerciseLog> _logs = [];
  int _totalSessions = 0;
  int _totalDays = 0;
  double _totalVolume = 0;

  String _query = '';
  _Sort _sort = _Sort.recent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (SupabaseService.currentUser == null) {
      setState(() {
        _isLoading = false;
        _error = 'Entre na sua conta para ver o histórico.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final entries = await SupabaseService.getAllGymEntries();
      final logs = ExerciseLog.group(entries);

      if (!mounted) return;
      setState(() {
        _logs = logs;
        _totalSessions = entries.length;
        _totalDays = entries.map((e) => e.entryDate).toSet().length;
        _totalVolume =
            entries.fold<double>(0, (sum, e) => sum + e.volume);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Falha ao carregar: $e';
        });
      }
    }
  }

  List<ExerciseLog> get _visible {
    final query = _query.trim().toLowerCase();
    final matches = _logs.where((log) {
      if (query.isEmpty) return true;
      final exercise = log.exercise;
      return exercise.name.toLowerCase().contains(query) ||
          (exercise.namePt ?? '').toLowerCase().contains(query) ||
          (exercise.muscleGroup ?? '').toLowerCase().contains(query);
    }).toList();

    switch (_sort) {
      case _Sort.recent:
        matches.sort((a, b) => b.lastDate.compareTo(a.lastDate));
      case _Sort.frequent:
        matches.sort((a, b) => b.sessions.compareTo(a.sessions));
      case _Sort.heaviest:
        // Bodyweight exercises have no weight to rank by, so they sink to
        // the bottom rather than scattering through the list.
        matches.sort((a, b) =>
            (b.prWeight ?? -1).compareTo(a.prWeight ?? -1));
    }
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(title: const Text('Histórico de treinos')),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primaryOrange))
            : _error != null
                ? _buildError()
                : _logs.isEmpty
                    ? _buildEmpty()
                    : _buildList(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!,
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(
              onPressed: _load, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Nenhum treino registrado ainda.',
          textAlign: TextAlign.center,
          style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
        ),
      ),
    );
  }

  Widget _buildList() {
    final visible = _visible;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSummaryCard(),
        const SizedBox(height: 16),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Buscar',
            prefixIcon:
                const Icon(Icons.search, color: AppTheme.mediumBrown),
            filled: true,
            fillColor: AppTheme.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final entry in _kSortLabels.entries)
                _buildSortChip(entry.value, entry.key),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Nenhum exercício encontrado.',
                style:
                    AppTheme.caption.copyWith(fontWeight: FontWeight.w400)),
          )
        else
          for (final log in visible) _buildLogCard(log),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(child: _buildStat('Exercícios', '${_logs.length}')),
          Expanded(child: _buildStat('Sessões', '$_totalSessions')),
          Expanded(child: _buildStat('Dias', '$_totalDays')),
          Expanded(
              child: _buildStat('Volume', formatVolume(_totalVolume))),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.caption),
        const SizedBox(height: 2),
        Text(value,
            style: AppTheme.headingMedium.copyWith(fontSize: 20),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildSortChip(String label, _Sort value) {
    final selected = _sort == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: selected ? null : AppTheme.softShadow,
        ),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _sort = value),
          selectedColor: AppTheme.primaryOrange,
          backgroundColor: AppTheme.white,
          checkmarkColor: AppTheme.white,
          elevation: 0,
          pressElevation: 0,
          shadowColor: Colors.transparent,
          labelStyle: TextStyle(
            color: selected ? AppTheme.white : AppTheme.mediumBrown,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
        ),
      ),
    );
  }

  Widget _buildLogCard(ExerciseLog log) {
    final exercise = log.exercise;
    final pr = log.prWeight;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => GymExerciseHistoryScreen(log: log)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ExerciseThumb(exercise: exercise, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercise.namePt ?? exercise.name,
                          style: AppTheme.valueBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        [
                          '${log.sessions} '
                              '${log.sessions == 1 ? 'sessão' : 'sessões'}',
                          'último ${formatDayMonth(log.lastDate)}',
                          if (exercise.muscleGroup != null)
                            exercise.muscleGroup!,
                        ].join(' · '),
                        style: AppTheme.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (pr != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'PR: ${formatWeight(pr)} kg',
                          style: AppTheme.caption
                              .copyWith(color: AppTheme.primaryOrange),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: AppTheme.mediumBrown.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
