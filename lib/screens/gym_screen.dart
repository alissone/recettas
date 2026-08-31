import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../app_theme.dart';
import '../models/exercise.dart';
import '../models/gym_entry.dart';
import '../services/supabase_service.dart';
import '../utils/dates.dart';
import '../widgets/exercise_thumb.dart';
import 'gym_exercise_history_screen.dart' show formatVolume;
import 'gym_history_screen.dart';

/// One day of training at a time: which exercises were done, how many
/// sets and reps, and at what weight. The exercise catalog itself is
/// seeded in SQL, so this screen only reads it.
class GymScreen extends StatefulWidget {
  const GymScreen({super.key});

  @override
  State<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> {
  /// Days shown by the volume trend chart, today included.
  static const _volumeChartDays = 14;

  bool _isLoading = true;
  DateTime _day = today();
  List<GymEntry> _entries = [];

  /// Every entry from the last [_volumeChartDays] days, across all
  /// exercises - independent of the selected [_day] - feeding the daily
  /// volume chart.
  List<GymEntry> _recentEntries = [];
  List<Exercise> _exercises = [];
  Map<String, double> _latestWeights = {};
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isAtToday => !_day.isBefore(today());

  /// One point per day for the last [_volumeChartDays] days (today
  /// included), zero-filled for rest days so the trend reads as a
  /// continuous timeline rather than only the days actually trained.
  List<MapEntry<DateTime, double>> get _dailyVolumePoints {
    final volumeByDay = <DateTime, double>{};
    for (final entry in _recentEntries) {
      final day = DateTime.parse(entry.entryDate);
      volumeByDay[day] = (volumeByDay[day] ?? 0) + entry.volume;
    }
    final end = today();
    final start = end.subtract(const Duration(days: _volumeChartDays - 1));
    return [
      for (var d = start;
          !d.isAfter(end);
          d = d.add(const Duration(days: 1)))
        MapEntry(d, volumeByDay[d] ?? 0),
    ];
  }

  Future<void> _load() async {
    if (SupabaseService.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    final seq = ++_loadSeq;
    try {
      // The catalog is static reference data: fetch it once.
      if (_exercises.isEmpty) {
        _exercises = await SupabaseService.getExercises();
      }
      final chartStart = today()
          .subtract(const Duration(days: _volumeChartDays - 1));
      final (entries, recentEntries, latestWeights) = await (
        SupabaseService.getGymEntries(
          fromDate: isoDate(_day),
          toDateExclusive: isoDate(_day.add(const Duration(days: 1))),
        ),
        SupabaseService.getGymEntries(
          fromDate: isoDate(chartStart),
          toDateExclusive: isoDate(today().add(const Duration(days: 1))),
        ),
        SupabaseService.getLatestExerciseWeights(),
      ).wait;
      if (mounted && seq == _loadSeq) {
        setState(() {
          _entries = entries;
          _recentEntries = recentEntries;
          _latestWeights = latestWeights;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && seq == _loadSeq) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao carregar: $e')));
      }
    }
  }

  void _changeDay(int delta) {
    final next = _day.add(Duration(days: delta));
    if (next.isAfter(today())) return;
    setState(() {
      _day = next;
      _isLoading = true;
    });
    _load();
  }

  /// Deletes every set group logged for this exercise today.
  Future<void> _deleteGroup(List<GymEntry> group) async {
    try {
      for (final entry in group) {
        await SupabaseService.deleteGymEntry(entry.id);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao excluir: $e')));
      }
    }
  }

  /// [_entries] grouped by exercise, in the order each exercise was first
  /// logged today - each group can hold several set groups (e.g. a top
  /// set plus drop sets).
  List<List<GymEntry>> get _groupedEntries {
    final byExercise = <String, List<GymEntry>>{};
    for (final entry in _entries) {
      byExercise.putIfAbsent(entry.exerciseId, () => []).add(entry);
    }
    return byExercise.values.toList();
  }

  /// Picks an exercise, then collects sets/reps/weight for it. Choosing
  /// an exercise already logged today pre-fills the sheet with its
  /// existing set groups.
  Future<void> _addEntry() async {
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Nenhum exercício cadastrado. Adicione-os no Supabase.')));
      return;
    }
    final exercise = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (_) => _ExercisePickerSheet(
        exercises: _exercises,
        latestWeights: _latestWeights,
      ),
    );
    if (exercise == null || !mounted) return;

    final existing =
        _entries.where((e) => e.exerciseId == exercise.id).toList();
    await _showEntrySheet(exercise, existing);
  }

  Future<void> _showEntrySheet(
      Exercise exercise, List<GymEntry> existing) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (_) => _GymEntrySheet(
        exercise: exercise,
        existing: existing,
        entryDate: isoDate(_day),
      ),
    );
    if (saved == true) await _load();
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        title: const Text('Academia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Histórico',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const GymHistoryScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primaryOrange))
            : SupabaseService.currentUser == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Entre na sua conta para registrar treinos.',
                        textAlign: TextAlign.center,
                        style: AppTheme.caption
                            .copyWith(fontWeight: FontWeight.w400),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 20),
                      _buildVolumeChartCard(),
                      const SizedBox(height: 20),
                      if (_entries.isEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'Nenhum exercício neste dia.\n'
                              'Toque em + para registrar.',
                              textAlign: TextAlign.center,
                              style: AppTheme.caption
                                  .copyWith(fontWeight: FontWeight.w400),
                            ),
                          ),
                        )
                      else
                        for (final group in _groupedEntries)
                          _buildEntryCard(group),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final exerciseCount = _entries.map((e) => e.exerciseId).toSet().length;
    final sets = _entries.fold<int>(0, (sum, e) => sum + e.sets);
    final volume = _entries.fold<double>(0, (sum, e) => sum + e.volume);

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
                onPressed: () => _changeDay(-1),
                icon: const Icon(Icons.chevron_left),
                color: AppTheme.mediumBrown,
                visualDensity: VisualDensity.compact,
                tooltip: 'Dia anterior',
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${kWeekdaysShort[_day.weekday - 1]} '
                    '${formatDayMonth(_day)}',
                    style: AppTheme.caption
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              IconButton(
                onPressed: _isAtToday ? null : () => _changeDay(1),
                icon: const Icon(Icons.chevron_right),
                color: AppTheme.mediumBrown,
                visualDensity: VisualDensity.compact,
                tooltip: 'Próximo dia',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStat('Exercícios', '$exerciseCount'),
              const SizedBox(width: 24),
              _buildStat('Séries', '$sets'),
              const SizedBox(width: 24),
              _buildStat('Volume',
                  volume > 0 ? '${volume.round()} kg' : '—'),
            ],
          ),
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
        Text(value, style: AppTheme.headingMedium),
      ],
    );
  }

  /// Same look as the "Peso corporal" -> "Últimos meses" chart in
  /// Nutrição, but one point per day (zero-filled) over the last two
  /// weeks instead of a weekly average.
  Widget _buildVolumeChartCard() {
    final points = _dailyVolumePoints;
    final hasVolume = points.any((p) => p.value > 0);

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
          const Text('Volume diário', style: AppTheme.sectionTitle),
          const SizedBox(height: 4),
          Text('Últimas 2 semanas',
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (!hasVolume)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Nenhum treino nos últimos 14 dias.',
                    style: AppTheme.caption
                        .copyWith(fontWeight: FontWeight.w400)),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => CustomPaint(
                size: Size(constraints.maxWidth, 140),
                painter: _VolumeLinePainter(points: points),
              ),
            ),
        ],
      ),
    );
  }

  /// One card per exercise logged today, listing every set group done for
  /// it (e.g. a top set plus drop sets) in a column below the title.
  Widget _buildEntryCard(List<GymEntry> group) {
    final exercise = group.first.exercise;

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
          onTap: exercise == null
              ? null
              : () => _showEntrySheet(exercise, group),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExerciseThumb(exercise: exercise, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercise?.namePt ?? 'Exercício',
                          style: AppTheme.valueBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (exercise?.muscleGroup != null) ...[
                        const SizedBox(height: 2),
                        Text(exercise!.muscleGroup!,
                            style: AppTheme.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 4),
                      for (final entry in group) _buildSetLine(entry),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteGroup(group),
                  icon: Icon(Icons.close,
                      size: 18,
                      color: AppTheme.mediumBrown
                          .withValues(alpha: 0.6)),
                  tooltip: 'Excluir',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetLine(GymEntry entry) {
    final weight = entry.weight;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        [
          entry.setsLabel,
          if (weight != null && weight > 0) '${formatWeight(weight)} kg',
          if (entry.notes != null && entry.notes!.isNotEmpty) entry.notes!,
        ].join(' · '),
        style: AppTheme.caption,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheets
// ---------------------------------------------------------------------------

/// Fixed display order for the category filter chips; any muscle_group
/// value outside this list (e.g. a user-added exercise) is appended
/// afterwards, alphabetically.
const _kCategoryOrder = [
  'Glúteos',
  'Peito',
  'Costas',
  'Ombros',
  'Bíceps',
  'Tríceps',
  'Pernas',
  'Panturrilha',
  'Corpo Inteiro',
];

/// Pinterest-style video gallery of the exercise catalog, searchable and
/// filterable by category. Pops the chosen exercise.
class _ExercisePickerSheet extends StatefulWidget {
  final List<Exercise> exercises;
  final Map<String, double> latestWeights;

  const _ExercisePickerSheet({
    required this.exercises,
    required this.latestWeights,
  });

  @override
  State<_ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

/// Grid card geometry, shared between the SliverGridDelegate and the
/// scroll-position math in _updateFocus so the two can't drift apart.
const _kCardExtent = 232.0;
const _kGridSpacing = 12.0;
const _kCrossAxisCount = 2;

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String _query = '';
  String? _category = 'Glúteos';
  final ScrollController _scrollController = ScrollController();

  /// Id of the single exercise whose video is allowed to play - the card
  /// under the user's finger, the way video sites preview on hover. Every
  /// other card shows its static poster frame, so at most one hardware
  /// video decoder is ever in use at a time (devices only expose a
  /// handful, and letting them all play means most silently never do).
  final ValueNotifier<String?> _focusedExerciseId = ValueNotifier(null);

  /// Last pointer position, local to the grid's viewport. Null once the
  /// finger lifts - the card it left keeps playing, so focus stops
  /// tracking until the next touch.
  Offset? _pointer;

  /// Grid viewport width, captured in build via LayoutBuilder; needed to
  /// work out which column the pointer is over.
  double _gridWidth = 0;

  List<String> get _categories {
    final present = widget.exercises
        .map((e) => e.muscleGroup)
        .whereType<String>()
        .toSet();
    final extra = present.difference(_kCategoryOrder.toSet()).toList()
      ..sort();
    return [..._kCategoryOrder.where(present.contains), ...extra];
  }

  List<Exercise> get _matches {
    final query = _query.trim().toLowerCase();
    return widget.exercises.where((e) {
      final matchesQuery = query.isEmpty ||
          e.name.toLowerCase().contains(query) ||
          (e.namePt ?? '').toLowerCase().contains(query) ||
          (e.muscleGroup ?? '').toLowerCase().contains(query);
      final matchesCategory =
          _category == null || e.muscleGroup == _category;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateFocus);
    // The initial `matches` list depends on the default category filter
    // above, so pick the first card as focused only after the first
    // frame rather than guessing during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFocus());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusedExerciseId.dispose();
    super.dispose();
  }

  /// Plays the card under [_pointer]. Called on every touch move and on
  /// every scroll tick - during a drag the content slides under a
  /// stationary finger, so the card being pointed at keeps changing even
  /// though the finger hasn't moved.
  ///
  /// With no finger down, focus is left alone: the card the finger lifted
  /// from goes on playing through the momentum scroll, rather than
  /// flickering between cards as they rush past.
  void _updateFocus() {
    final matches = _matches;
    if (matches.isEmpty) {
      _focusedExerciseId.value = null;
      return;
    }

    final pointer = _pointer;
    if (pointer == null || !_scrollController.hasClients || _gridWidth <= 0) {
      // Nothing pointed at yet: seed with the first card so the gallery
      // isn't completely static before the first touch.
      _focusedExerciseId.value ??= matches.first.id;
      return;
    }

    const rowExtent = _kCardExtent + _kGridSpacing;
    final columnExtent =
        (_gridWidth + _kGridSpacing) / _kCrossAxisCount;

    final contentY = _scrollController.offset + pointer.dy;
    final rowCount = (matches.length / _kCrossAxisCount).ceil();
    final row = (contentY / rowExtent).floor();
    final column = (pointer.dx / columnExtent).floor();

    // Ignore touches in the gutters or outside the grid rather than
    // snapping to a neighbour the finger isn't actually over.
    if (row < 0 || row >= rowCount) return;
    if (column < 0 || column >= _kCrossAxisCount) return;

    final index = row * _kCrossAxisCount + column;
    if (index < 0 || index >= matches.length) return;
    _focusedExerciseId.value = matches[index].id;
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Escolher exercício', style: AppTheme.headingMedium),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) {
              setState(() => _query = v);
              _updateFocus();
            },
            decoration: InputDecoration(
              hintText: 'Buscar',
              prefixIcon: const Icon(Icons.search,
                  color: AppTheme.mediumBrown),
              filled: true,
              fillColor: AppTheme.white,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSmall),
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
                _buildCategoryChip('Todos', null),
                for (final category in _categories)
                  _buildCategoryChip(category, category),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75),
            child: matches.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('Nenhum exercício encontrado.',
                        style: AppTheme.caption
                            .copyWith(fontWeight: FontWeight.w400)),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      _gridWidth = constraints.maxWidth;
                      // Listener rather than a gesture recognizer: this
                      // has to observe the same touch the GridView is
                      // using to scroll, not compete with it for the
                      // gesture arena.
                      return Listener(
                        onPointerDown: (event) {
                          _pointer = event.localPosition;
                          _updateFocus();
                        },
                        onPointerMove: (event) {
                          _pointer = event.localPosition;
                          _updateFocus();
                        },
                        onPointerUp: (_) => _pointer = null,
                        onPointerCancel: (_) => _pointer = null,
                        child: GridView.builder(
                          controller: _scrollController,
                          shrinkWrap: true,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _kCrossAxisCount,
                            mainAxisSpacing: _kGridSpacing,
                            crossAxisSpacing: _kGridSpacing,
                            mainAxisExtent: _kCardExtent,
                          ),
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final exercise = matches[index];
                            return _ExerciseGalleryCard(
                              key: ValueKey(exercise.id),
                              exercise: exercise,
                              latestWeight:
                                  widget.latestWeights[exercise.id],
                              focusedId: _focusedExerciseId,
                              onTap: () =>
                                  Navigator.pop(context, exercise),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? value) {
    final selected = _category == value;
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
          onSelected: (_) {
            setState(() => _category = value);
            _updateFocus();
          },
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
}

/// One card in the exercise gallery: a looping muted video preview, the
/// Portuguese name, the English catalog name underneath, and the latest
/// recorded weight for that exercise, if any.
class _ExerciseGalleryCard extends StatelessWidget {
  final Exercise exercise;
  final double? latestWeight;
  final ValueListenable<String?> focusedId;
  final VoidCallback onTap;

  const _ExerciseGalleryCard({
    super.key,
    required this.exercise,
    required this.latestWeight,
    required this.focusedId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final weight = latestWeight;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusXSmall),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: _ExerciseVideoThumbnail(
                      path: exercise.videoPath,
                      exerciseId: exercise.id,
                      focusedId: focusedId,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  exercise.namePt ?? exercise.name,
                  style: AppTheme.valueBold.copyWith(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (exercise.namePt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    exercise.name,
                    style: AppTheme.caption.copyWith(
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (weight != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'PR: ${formatWeight(weight)} kg',
                    style: AppTheme.caption
                        .copyWith(color: AppTheme.primaryOrange),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A looping, muted preview of a local exercise video from
/// assets/exercises/, but only while this card is the gallery's single
/// "focused" one (see _ExercisePickerSheetState._focusedExerciseId) -
/// real devices only expose a handful of concurrent hardware video
/// decoder sessions system-wide, so letting every visible card play at
/// once means most of them lose the race for a decoder and never play,
/// which one "wins" effectively random. Falls back to a static
/// placeholder icon otherwise (loading, unfocused, or unplayable).
class _ExerciseVideoThumbnail extends StatefulWidget {
  final String? path;
  final String exerciseId;
  final ValueListenable<String?> focusedId;

  const _ExerciseVideoThumbnail({
    required this.path,
    required this.exerciseId,
    required this.focusedId,
  });

  @override
  State<_ExerciseVideoThumbnail> createState() =>
      _ExerciseVideoThumbnailState();
}

class _ExerciseVideoThumbnailState extends State<_ExerciseVideoThumbnail>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;

  // Tracks whether this widget actually saw AppLifecycleState.paused (a
  // real backgrounding: screen off, home button, app switch). Opening a
  // showModalBottomSheet can itself fire a transient
  // inactive -> resumed blip as part of the route's open animation even
  // though the app never left the foreground; reinitializing on every
  // such blip raced dozens of still-in-flight controller inits against
  // each other and left only one video surviving. Gating the rebuild
  // behind a genuine prior pause avoids that storm while still fixing
  // the real screen-off/on black-frame case.
  bool _wasPaused = false;

  bool get _isFocused => widget.focusedId.value == widget.exerciseId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.focusedId.addListener(_onFocusChanged);
    _onFocusChanged();
  }

  void _onFocusChanged() {
    if (_isFocused) {
      if (_controller == null) _init();
    } else {
      _teardown();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android tears down the decoder's GPU texture while the screen is
    // off; simply resuming playback afterwards leaves the frame black, so
    // the controller has to be rebuilt from scratch (the same thing that
    // happens naturally when this widget is unmounted and remounted).
    if (state == AppLifecycleState.paused) {
      _wasPaused = true;
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed &&
        _wasPaused &&
        _isFocused) {
      _wasPaused = false;
      _reinit();
    }
  }

  Future<void> _init() async {
    final path = widget.path;
    if (path == null || path.isEmpty) return;
    final controller = VideoPlayerController.asset(path);
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted || !_isFocused) {
        controller.dispose();
        if (identical(_controller, controller)) _controller = null;
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      setState(() {});
    } catch (_) {
      // build() falls back to the placeholder when the controller never
      // reaches an initialized state.
    }
  }

  Future<void> _reinit() async {
    final old = _controller;
    _controller = null;
    if (mounted) setState(() {});
    await old?.dispose();
    if (mounted && _isFocused) await _init();
  }

  void _teardown() {
    final old = _controller;
    if (old == null) return;
    _controller = null;
    if (mounted) setState(() {});
    old.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.focusedId.removeListener(_onFocusChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null &&
        controller.value.isInitialized &&
        !controller.value.hasError;

    // The poster always sits underneath, so an unfocused card still shows
    // its exercise (YouTube-style) instead of a blank placeholder, and the
    // focused one has something to display during the brief gap while its
    // controller initializes.
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildPoster(),
        if (ready)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
      ],
    );
  }

  /// Still frame for this exercise, pre-extracted from the video with
  /// ffmpeg into assets/exercise_posters/ (same basename, .jpg).
  Widget _buildPoster() {
    final poster = exercisePosterPath(widget.path);
    if (poster == null) return _buildPlaceholder();
    return Image.asset(
      poster,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.lightPeach,
      alignment: Alignment.center,
      child: Icon(Icons.fitness_center,
          color: AppTheme.mediumBrown.withValues(alpha: 0.5)),
    );
  }
}

/// One set-group card's mutable form state: [id] is the backing
/// [GymEntry]'s id for an existing set group, null for one added in this
/// session that doesn't exist in the database yet.
class _SetForm {
  final String? id;
  int sets;
  int reps;

  /// Kilograms; 0 means no weight (bodyweight work), same as the null
  /// this saves as.
  double weight;
  final TextEditingController notesController;

  _SetForm({
    this.id,
    required this.sets,
    required this.reps,
    this.weight = 0,
    String? notes,
  }) : notesController = TextEditingController(text: notes ?? '');

  void dispose() {
    notesController.dispose();
  }
}

/// Every set group of one exercise on one day - sets, reps, weight and
/// notes each - so drop sets can be recorded alongside the main set.
/// Pops `true` after a successful save.
class _GymEntrySheet extends StatefulWidget {
  final Exercise exercise;
  final List<GymEntry> existing;
  final String entryDate;

  const _GymEntrySheet({
    required this.exercise,
    required this.existing,
    required this.entryDate,
  });

  @override
  State<_GymEntrySheet> createState() => _GymEntrySheetState();
}

class _GymEntrySheetState extends State<_GymEntrySheet> {
  late List<_SetForm> _forms;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _forms = widget.existing.isEmpty
        ? [_SetForm(sets: 3, reps: 12)]
        : [
            for (final entry in widget.existing)
              _SetForm(
                id: entry.id,
                sets: entry.sets,
                reps: entry.reps,
                weight: entry.weight ?? 0,
                notes: entry.notes,
              ),
          ];
  }

  @override
  void dispose() {
    for (final form in _forms) {
      form.dispose();
    }
    super.dispose();
  }

  void _addSet() {
    final last = _forms.last;
    setState(() => _forms.add(_SetForm(sets: last.sets, reps: last.reps)));
  }

  void _removeSet(int index) {
    setState(() => _forms.removeAt(index).dispose());
  }

  /// Saves every set-group card: updates the ones backed by an existing
  /// row, inserts the ones added this session, and deletes any existing
  /// row whose card was removed.
  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final keptIds = <String>{};
      for (final form in _forms) {
        final notes = form.notesController.text.trim();
        await SupabaseService.saveGymEntrySet(
          id: form.id,
          entryDate: widget.entryDate,
          exerciseId: widget.exercise.id,
          sets: form.sets,
          reps: form.reps,
          weight: form.weight > 0 ? form.weight : null,
          notes: notes.isEmpty ? null : notes,
        );
        if (form.id != null) keptIds.add(form.id!);
      }
      for (final entry in widget.existing) {
        if (!keptIds.contains(entry.id)) {
          await SupabaseService.deleteGymEntry(entry.id);
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao salvar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExerciseThumb(exercise: widget.exercise, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(widget.exercise.namePt ?? widget.exercise.name,
                      style: AppTheme.headingMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < _forms.length; i++) ...[
              _buildSetCard(i),
              const SizedBox(height: 12),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addSet,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar série'),
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryOrange),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                ),
                child: Text(_isSaving ? 'Salvando...' : 'Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One set group's fields, bordered just enough to read as its own
  /// card, with a small button at the top-left to remove it.
  Widget _buildSetCard(int index) {
    final form = _forms[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
            color: AppTheme.mediumBrown.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _removeSet(index),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close,
                  size: 18,
                  color: AppTheme.mediumBrown.withValues(alpha: 0.6)),
            ),
          ),
          const SizedBox(height: 4),
          _buildStepper(
            label: 'Séries',
            value: form.sets,
            onChanged: (v) => setState(() => form.sets = v),
          ),
          const SizedBox(height: 12),
          _buildStepper(
            label: 'Repetições',
            value: form.reps,
            onChanged: (v) => setState(() => form.reps = v),
          ),
          const SizedBox(height: 12),
          _buildWeightStepper(
            value: form.weight,
            onChanged: (v) => setState(() => form.weight = v),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openNotesScreen(form),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar notas'),
              style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryOrange),
            ),
          ),
          if (form.notesController.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(form.notesController.text.trim(),
                  style: AppTheme.caption
                      .copyWith(fontWeight: FontWeight.w400),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }

  /// Full-screen so notes can run as long as the user wants; edits the
  /// card's controller directly, since it's the same instance.
  Future<void> _openNotesScreen(_SetForm form) async {
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _NotesScreen(
        exerciseName: widget.exercise.namePt ?? widget.exercise.name,
        controller: form.notesController,
      ),
    ));
    setState(() {});
  }

  /// Step size in kg for the weight +/- buttons - the smallest plate
  /// increment lifters typically load per side.
  static const _weightStep = 2.5;

  Widget _buildWeightStepper({
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        const Expanded(child: Text('Peso (kg)', style: AppTheme.bodyText)),
        IconButton(
          onPressed: value > 0
              ? () => onChanged(math.max(0, value - _weightStep))
              : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: AppTheme.mediumBrown,
        ),
        SizedBox(
          width: 56,
          child: Text(value > 0 ? formatWeight(value) : '—',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.headingMedium),
        ),
        IconButton(
          onPressed: () => onChanged(value + _weightStep),
          icon: const Icon(Icons.add_circle_outline),
          color: AppTheme.primaryOrange,
        ),
      ],
    );
  }

  Widget _buildStepper({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTheme.bodyText)),
        IconButton(
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: AppTheme.mediumBrown,
        ),
        SizedBox(
          width: 40,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: AppTheme.headingMedium),
        ),
        IconButton(
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
          color: AppTheme.primaryOrange,
        ),
      ],
    );
  }
}

/// Full-screen notes editor for one set group, so there's no cramped
/// single-line field limiting how much the user writes. Edits
/// [controller] directly - the caller owns it and reads it back after
/// this pops.
class _NotesScreen extends StatelessWidget {
  final String exerciseName;
  final TextEditingController controller;

  const _NotesScreen({required this.exerciseName, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        title:
            Text(exerciseName, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: AppTheme.bodyText,
            decoration: InputDecoration(
              hintText: 'Observações...',
              filled: true,
              fillColor: AppTheme.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Volume chart
// ---------------------------------------------------------------------------

/// Same visual recipe as Nutrição's weight trend chart: a light grid, one
/// orange line through the points, and up to ~6 evenly spread x labels.
/// Volume is never negative, so the y axis is pinned at zero rather than
/// padded around the data's own min/max.
class _VolumeLinePainter extends CustomPainter {
  final List<MapEntry<DateTime, double>> points;

  _VolumeLinePainter({required this.points});

  static const _leftLabelWidth = 40.0;
  static const _bottomAxisHeight = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotLeft = _leftLabelWidth;
    final plotWidth = size.width - plotLeft - 4;
    final plotBottom = size.height - _bottomAxisHeight;
    if (plotWidth <= 0 || plotBottom <= 0) return;

    const minY = 0.0;
    final rawMax = points.fold<double>(0, (m, p) => math.max(m, p.value));
    final maxY = rawMax <= 0 ? 1.0 : rawMax * 1.15;

    final gridPaint = Paint()
      ..color = AppTheme.mediumBrown.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = plotBottom - plotBottom * fraction;
      canvas.drawLine(
          Offset(plotLeft, y), Offset(size.width, y), gridPaint);
      _paintText(
        canvas,
        _axisLabel(minY + (maxY - minY) * fraction),
        Offset(plotLeft - 6, y),
        anchorRight: true,
        style: TextStyle(
          fontSize: 9,
          color: AppTheme.mediumBrown.withValues(alpha: 0.7),
        ),
      );
    }

    double xFor(int i) => points.length == 1
        ? plotLeft + plotWidth / 2
        : plotLeft + plotWidth * i / (points.length - 1);
    double yFor(double value) => plotBottom -
        plotBottom * ((value - minY) / (maxY - minY)).clamp(0.0, 1.0);

    if (points.length > 1) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final offset = Offset(xFor(i), yFor(points[i].value));
        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppTheme.primaryOrange
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }

    final dotPaint = Paint()..color = AppTheme.primaryOrange;
    // At most ~6 x-axis labels, evenly spread, always including the ends.
    final labelEvery = math.max(1, (points.length / 6).ceil());
    for (var i = 0; i < points.length; i++) {
      final x = xFor(i);
      final y = yFor(points[i].value);
      canvas.drawCircle(Offset(x, y), 3, dotPaint);

      final isLast = i == points.length - 1;
      if (i % labelEvery == 0 || isLast) {
        _paintText(
          canvas,
          formatDayMonth(points[i].key),
          Offset(x, plotBottom + _bottomAxisHeight / 2),
          anchorCenter: true,
          style: TextStyle(
            fontSize: 9,
            color: AppTheme.mediumBrown.withValues(alpha: 0.7),
          ),
        );
      }
    }
  }

  String _axisLabel(double kg) => kg <= 0 ? '0' : formatVolume(kg);

  void _paintText(
    Canvas canvas,
    String text,
    Offset position, {
    required TextStyle style,
    bool anchorRight = false,
    bool anchorCenter = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    var offset = Offset(position.dx, position.dy - painter.height / 2);
    if (anchorRight) {
      offset = offset.translate(-painter.width, 0);
    } else if (anchorCenter) {
      offset = offset.translate(-painter.width / 2, 0);
    }
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_VolumeLinePainter oldDelegate) =>
      oldDelegate.points != points;
}
