import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../app_theme.dart';
import '../models/exercise.dart';
import '../models/gym_entry.dart';
import '../services/supabase_service.dart';
import '../utils/dates.dart';
import '../widgets/remote_image.dart';

/// One day of training at a time: which exercises were done, how many
/// sets and reps, and at what weight. The exercise catalog itself is
/// seeded in SQL, so this screen only reads it.
class GymScreen extends StatefulWidget {
  const GymScreen({super.key});

  @override
  State<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> {
  bool _isLoading = true;
  DateTime _day = today();
  List<GymEntry> _entries = [];
  List<Exercise> _exercises = [];
  Map<String, double> _latestWeights = {};
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isAtToday => !_day.isBefore(today());

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
      final entries = await SupabaseService.getGymEntries(
        fromDate: isoDate(_day),
        toDateExclusive: isoDate(_day.add(const Duration(days: 1))),
      );
      final latestWeights = await SupabaseService.getLatestExerciseWeights();
      if (mounted && seq == _loadSeq) {
        setState(() {
          _entries = entries;
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

  Future<void> _deleteEntry(GymEntry entry) async {
    try {
      await SupabaseService.deleteGymEntry(entry.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao excluir: $e')));
      }
    }
  }

  /// Picks an exercise, then collects sets/reps/weight for it. Choosing
  /// an exercise already logged today pre-fills the sheet and overwrites
  /// the row on save.
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
        _entries.where((e) => e.exerciseId == exercise.id).firstOrNull;
    await _showEntrySheet(exercise, existing);
  }

  Future<void> _showEntrySheet(
      Exercise exercise, GymEntry? existing) async {
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
      appBar: AppBar(title: const Text('Academia')),
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
                        for (final entry in _entries)
                          _buildEntryCard(entry),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSummaryCard() {
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
              _buildStat('Exercícios', '${_entries.length}'),
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

  Widget _buildEntryCard(GymEntry entry) {
    final exercise = entry.exercise;
    final weight = entry.weight;

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
              : () => _showEntrySheet(exercise, entry),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _ExerciseThumb(exercise: exercise, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercise?.namePt ?? 'Exercício',
                          style: AppTheme.valueBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        [
                          entry.setsLabel,
                          if (weight != null && weight > 0)
                            '${_trimWeight(weight)} kg',
                          if (exercise?.muscleGroup != null)
                            exercise!.muscleGroup!,
                        ].join(' · '),
                        style: AppTheme.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (entry.notes != null &&
                          entry.notes!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(entry.notes!,
                            style: AppTheme.caption.copyWith(
                                fontWeight: FontWeight.w400),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteEntry(entry),
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
}

String _trimWeight(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

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
                    'PR: ${_trimWeight(weight)} kg',
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
    final poster = _posterPath(widget.path);
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

/// 'assets/exercises/Foo.mp4' -> 'assets/exercise_posters/Foo.jpg'. The
/// posters are generated from the videos themselves, so deriving the path
/// keeps them in sync without a second database column.
String? _posterPath(String? videoPath) {
  if (videoPath == null || !videoPath.endsWith('.mp4')) return null;
  final name = videoPath.split('/').last;
  final base = name.substring(0, name.length - 4);
  return 'assets/exercise_posters/$base.jpg';
}

/// Square thumbnail for one exercise: the poster frame pulled from its
/// video, falling back to the hand-uploaded photo in the "habits" bucket
/// and then to a placeholder icon. The seeded catalog has videos but no
/// image_path, so without the poster these all render as bare icons.
class _ExerciseThumb extends StatelessWidget {
  final Exercise? exercise;
  final double size;

  const _ExerciseThumb({required this.exercise, required this.size});

  @override
  Widget build(BuildContext context) {
    final fallback = RemoteImage(
      path: exercise?.imagePath,
      width: size,
      height: size,
      placeholder: Icons.fitness_center,
    );
    final poster = _posterPath(exercise?.videoPath);
    if (poster == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusXSmall),
      child: Image.asset(
        poster,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// Sets, reps and weight for one exercise on one day. Pops `true` after
/// a successful save.
class _GymEntrySheet extends StatefulWidget {
  final Exercise exercise;
  final GymEntry? existing;
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
  late int _sets;
  late int _reps;
  late final TextEditingController _weightController;
  late final TextEditingController _notesController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _sets = existing?.sets ?? 3;
    _reps = existing?.reps ?? 12;
    _weightController = TextEditingController(
        text: existing?.weight != null
            ? _trimWeight(existing!.weight!)
            : '');
    _notesController =
        TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final notes = _notesController.text.trim();
      await SupabaseService.upsertGymEntry(
        entryDate: widget.entryDate,
        exerciseId: widget.exercise.id,
        sets: _sets,
        reps: _reps,
        weight: double.tryParse(
            _weightController.text.trim().replaceAll(',', '.')),
        notes: notes.isEmpty ? null : notes,
      );
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ExerciseThumb(exercise: widget.exercise, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Text(widget.exercise.name,
                    style: AppTheme.headingMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStepper(
            label: 'Séries',
            value: _sets,
            onChanged: (v) => setState(() => _sets = v),
          ),
          const SizedBox(height: 12),
          _buildStepper(
            label: 'Repetições',
            value: _reps,
            onChanged: (v) => setState(() => _reps = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weightController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoration('Peso em kg (opcional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: _decoration('Observações (opcional)'),
          ),
          const SizedBox(height: 20),
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
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          TextStyle(color: AppTheme.mediumBrown.withValues(alpha: 0.8)),
      filled: true,
      fillColor: AppTheme.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        borderSide:
            const BorderSide(color: AppTheme.primaryOrange, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
