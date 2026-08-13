import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../app_theme.dart';
import '../models/habit.dart';
import '../services/supabase_service.dart';
import '../utils/dates.dart';
import '../widgets/icon_color_picker.dart';
import '../widgets/remote_image.dart';
import 'habit_detail_screen.dart';

/// List of the user's habits with the progress of the current period and
/// a one-tap way to log another repeat. A day strip above the list picks
/// which day is being logged (defaults to today). Tapping a habit opens
/// its calendar; the "+" button logs one unit (long-press removes one),
/// and long-pressing the card itself logs a custom amount.
class HabitListScreen extends StatefulWidget {
  const HabitListScreen({super.key});

  @override
  State<HabitListScreen> createState() => _HabitListScreenState();
}

class _HabitListScreenState extends State<HabitListScreen> {
  bool _isLoading = true;
  List<Habit> _habits = [];
  List<HabitLog> _logs = [];

  /// habitId -> total logged in the habit's current period, relative to
  /// [_selectedDay].
  Map<String, double> _periodValues = {};
  int _loadSeq = 0;

  /// Day the list is showing/logging for; the strip above the list picks
  /// this. Defaults to today.
  DateTime _selectedDay = today();
  final _dayScrollController = ScrollController();

  /// How far back the day strip scrolls; older days stay reachable
  /// through each habit's own calendar.
  static const _carouselDays = 60;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollToToday();
  }

  @override
  void dispose() {
    _dayScrollController.dispose();
    super.dispose();
  }

  void _scrollToToday() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _dayScrollController.hasClients) {
        _dayScrollController
            .jumpTo(_dayScrollController.position.maxScrollExtent);
      }
    });
  }

  Map<String, double> _computeValues(DateTime day) {
    final values = <String, double>{};
    for (final habit in _habits) {
      final start = habit.periodStart(day);
      final end = habit.periodEnd(day);
      var total = 0.0;
      for (final log in _logs) {
        if (log.habitId != habit.id) continue;
        final d = DateTime.tryParse(log.logDate);
        if (d == null) continue;
        if (d.isBefore(start) || !d.isBefore(end)) continue;
        total += log.value;
      }
      values[habit.id] = total;
    }
    return values;
  }

  void _selectDay(DateTime day) {
    if (day == _selectedDay) return;
    setState(() {
      _selectedDay = day;
      _periodValues = _computeValues(day);
    });
  }

  Future<void> _load() async {
    if (SupabaseService.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    final seq = ++_loadSeq;
    try {
      final habits = await SupabaseService.getHabits();
      // Wide enough to cover every day in the carousel, plus the whole
      // month of the oldest one so monthly goals resolve correctly.
      final oldest =
          today().subtract(const Duration(days: _carouselDays - 1));
      final from = DateTime(oldest.year, oldest.month, 1);
      final logs = await SupabaseService.getHabitLogs(
        fromDate: isoDate(from),
        toDateExclusive: isoDate(today().add(const Duration(days: 1))),
      );

      if (mounted && seq == _loadSeq) {
        setState(() {
          _habits = habits;
          _logs = logs;
          _periodValues = _computeValues(_selectedDay);
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

  /// Logs [delta] for the selected day; a negative delta removes that
  /// much from the period total instead (clamped so it never goes
  /// below zero).
  Future<void> _addLog(Habit habit, double delta) async {
    if (delta == 0) return;
    var value = delta;
    if (value < 0) {
      final current = _periodValues[habit.id] ?? 0;
      if (current <= 0) return;
      if (-value > current) value = -current;
    }
    try {
      await SupabaseService.addHabitLog(
        habitId: habit.id,
        logDate: isoDate(_selectedDay),
        value: value,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao registrar: $e')));
      }
    }
  }

  /// Long-press flow: type how much was done instead of adding one.
  Future<void> _addCustomLog(Habit habit) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text(habit.name, style: AppTheme.headingMedium),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: habit.isDuration ? 'Minutos' : habit.unitLabel,
            filled: true,
            fillColor: AppTheme.white,
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusSmall),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: TextStyle(color: AppTheme.mediumBrown)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
    if (value != null) await _addLog(habit, value);
  }

  Future<void> _showEditor({Habit? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (_) => HabitSheet(existing: existing),
    );
    if (saved == true) await _load();
  }

  Future<void> _openDetail(Habit habit) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HabitDetailScreen(habit: habit)),
    );
    if (mounted) await _load();
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final authenticated = SupabaseService.currentUser != null;
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(title: const Text('Hábitos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (authenticated) _buildDaySelector(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryOrange))
                  : !authenticated
                      ? _buildMessage(
                          'Entre na sua conta para acompanhar seus hábitos.')
                      : _habits.isEmpty
                          ? _buildMessage(
                              'Nenhum hábito ainda.\n'
                              'Toque em + para criar o primeiro.')
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: AppTheme.primaryOrange,
                              child: ListView.builder(
                                // Short lists still have to drag to refresh.
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                    20, 12, 20, 96),
                                itemCount: _habits.length,
                                itemBuilder: (context, index) =>
                                    _buildHabitCard(_habits[index]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    return SizedBox(
      height: 56,
      child: ListView.builder(
        controller: _dayScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        itemCount: _carouselDays,
        itemBuilder: (context, index) {
          final day =
              today().subtract(Duration(days: _carouselDays - 1 - index));
          return _buildDayPill(day);
        },
      ),
    );
  }

  Widget _buildDayPill(DateTime day) {
    final isSelected = day == _selectedDay;
    final isToday = day == today();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? AppTheme.primaryOrange : AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        elevation: isSelected ? 2 : 0,
        shadowColor: AppTheme.primaryOrange.withValues(alpha: 0.3),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          onTap: () => _selectDay(day),
          child: Container(
            width: 52,
            alignment: Alignment.center,
            child: Text(
              isToday ? 'Hoje' : '${day.day}',
              style: AppTheme.valueBold.copyWith(
                color: isSelected ? Colors.white : AppTheme.darkBrown,
                fontSize: isToday ? 13 : 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
        ),
      ),
    );
  }

  Widget _buildHabitCard(Habit habit) {
    final value = _periodValues[habit.id] ?? 0;
    final fraction =
        habit.goalTarget > 0 ? value / habit.goalTarget : 0.0;
    final isComplete = fraction >= 1;

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
          onTap: () => _openDetail(habit),
          onLongPress: () => _addCustomLog(habit),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: habit.color,
                    borderRadius: BorderRadius.circular(
                        AppTheme.radiusSmall),
                  ),
                  child: Icon(habit.icon,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(habit.name,
                          style: AppTheme.valueBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        '${habit.formatValue(value)} de '
                        '${habit.formatValue(habit.goalTarget)} '
                        '${habit.periodLabel}',
                        style: AppTheme.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor:
                              habit.color.withValues(alpha: 0.15),
                          valueColor:
                              AlwaysStoppedAnimation(habit.color),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onLongPress: () =>
                      _addLog(habit, habit.isDuration ? -5 : -1),
                  child: IconButton(
                    onPressed: () =>
                        _addLog(habit, habit.isDuration ? 5 : 1),
                    icon: Icon(
                      isComplete
                          ? Icons.check_circle
                          : Icons.add_circle_outline,
                      color: isComplete
                          ? const Color(0xFF43A047)
                          : habit.color,
                      size: 30,
                    ),
                    tooltip: habit.isDuration
                        ? 'Toque: +5 min · segure: -5 min'
                        : 'Toque: +1 · segure: -1',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create / edit sheet
// ---------------------------------------------------------------------------

/// Bottom sheet that creates or edits a habit. Pops `true` when
/// something was saved so the caller knows to reload.
class HabitSheet extends StatefulWidget {
  final Habit? existing;

  const HabitSheet({super.key, this.existing});

  @override
  State<HabitSheet> createState() => _HabitSheetState();
}

class _HabitSheetState extends State<HabitSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _targetController;
  late final TextEditingController _unitController;

  late String _iconName;
  late int _colorValue;
  late HabitGoalType _goalType;
  late HabitPeriod _period;
  String? _imagePath;

  /// Duration goals are stored in minutes; the user may type hours.
  bool _targetInHours = false;
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _unitController =
        TextEditingController(text: existing?.goalUnit ?? '');
    _iconName = existing?.iconName ?? 'check_circle';
    _colorValue = existing?.colorValue ?? 0xFFFF8C42;
    _goalType = existing?.goalType ?? HabitGoalType.counter;
    _period = existing?.period ?? HabitPeriod.daily;
    _imagePath = existing?.imagePath;

    // Show a round number of hours when that's what was stored.
    final target = existing?.goalTarget ?? 1;
    if (existing != null &&
        existing.isDuration &&
        target >= 60 &&
        target % 60 == 0) {
      _targetInHours = true;
      _targetController =
          TextEditingController(text: _trim(target / 60));
    } else {
      _targetController = TextEditingController(text: _trim(target));
    }
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  bool get _isDuration => _goalType == HabitGoalType.duration;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      return;
    }
    if (file == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await file.readAsBytes();
      final path = '${SupabaseService.currentUser!.id}/habits/'
          '${const Uuid().v4()}.jpg';
      await SupabaseService.uploadHabitImage(path, bytes);
      if (mounted) setState(() => _imagePath = path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao enviar imagem: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dê um nome ao hábito.')));
      return;
    }
    var target = double.tryParse(
            _targetController.text.trim().replaceAll(',', '.')) ??
        0;
    if (_isDuration && _targetInHours) target *= 60;
    if (target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Defina uma meta maior que zero.')));
      return;
    }

    final description = _descriptionController.text.trim();
    final unit = _unitController.text.trim();

    setState(() => _isSaving = true);
    try {
      if (widget.existing != null) {
        await SupabaseService.updateHabit(widget.existing!.id, {
          'name': name,
          'description': description.isEmpty ? null : description,
          'icon_name': _iconName,
          'color_value': _colorValue,
          'image_path': _imagePath,
          'goal_type': _goalType.name,
          'goal_target': target,
          'goal_unit': _isDuration || unit.isEmpty ? null : unit,
          'period': _period.name,
        });
      } else {
        await SupabaseService.addHabit(
          name: name,
          description: description.isEmpty ? null : description,
          iconName: _iconName,
          colorValue: _colorValue,
          imagePath: _imagePath,
          goalType: _goalType,
          goalTarget: target,
          goalUnit: _isDuration || unit.isEmpty ? null : unit,
          period: _period,
        );
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing != null ? 'Editar hábito' : 'Novo hábito',
              style: AppTheme.headingMedium,
            ),
            const SizedBox(height: 16),
            _buildField(_nameController, 'Nome', autofocus: true),
            const SizedBox(height: 12),
            _buildField(_descriptionController, 'Descrição (opcional)'),
            const SizedBox(height: 20),
            Text('Cor', style: AppTheme.caption.copyWith(fontSize: 14)),
            const SizedBox(height: 12),
            ColorSwatchPicker(
              selected: _colorValue,
              onChanged: (c) => setState(() => _colorValue = c),
            ),
            const SizedBox(height: 20),
            Text('Ícone', style: AppTheme.caption.copyWith(fontSize: 14)),
            const SizedBox(height: 12),
            HabitIconPicker(
              selected: _iconName,
              colorValue: _colorValue,
              onChanged: (name) => setState(() => _iconName = name),
            ),
            const SizedBox(height: 20),
            _buildImageRow(),
            const SizedBox(height: 20),
            Text('Meta', style: AppTheme.caption.copyWith(fontSize: 14)),
            const SizedBox(height: 12),
            SegmentedButton<HabitGoalType>(
              segments: const [
                ButtonSegment(
                    value: HabitGoalType.counter, label: Text('Contador')),
                ButtonSegment(
                    value: HabitGoalType.duration, label: Text('Duração')),
              ],
              selected: {_goalType},
              onSelectionChanged: (s) =>
                  setState(() => _goalType = s.first),
              showSelectedIcon: false,
              style: _segmentStyle,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    _targetController,
                    _isDuration
                        ? (_targetInHours ? 'Horas' : 'Minutos')
                        : 'Quantidade',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                if (_isDuration)
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('min')),
                      ButtonSegment(value: true, label: Text('h')),
                    ],
                    selected: {_targetInHours},
                    onSelectionChanged: (s) =>
                        setState(() => _targetInHours = s.first),
                    showSelectedIcon: false,
                    style: _segmentStyle,
                  )
                else
                  Expanded(
                    child: _buildField(
                        _unitController, 'Unidade (ex.: copos)'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<HabitPeriod>(
              segments: const [
                ButtonSegment(
                    value: HabitPeriod.daily, label: Text('Diário')),
                ButtonSegment(
                    value: HabitPeriod.weekly, label: Text('Semanal')),
                ButtonSegment(
                    value: HabitPeriod.monthly, label: Text('Mensal')),
              ],
              selected: {_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
              showSelectedIcon: false,
              style: _segmentStyle,
            ),
            const SizedBox(height: 24),
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

  ButtonStyle get _segmentStyle => SegmentedButton.styleFrom(
        selectedBackgroundColor:
            AppTheme.primaryOrange.withValues(alpha: 0.15),
        selectedForegroundColor: AppTheme.primaryOrange,
        visualDensity: VisualDensity.compact,
        side: BorderSide(color: AppTheme.borderOrange),
      );

  Widget _buildImageRow() {
    return Row(
      children: [
        RemoteImage(
          path: _imagePath,
          width: 56,
          height: 56,
          placeholder: habitIcon(_iconName),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            _imagePath == null
                ? 'Nenhuma imagem'
                : 'Imagem enviada',
            style: AppTheme.caption,
          ),
        ),
        if (_isUploading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.primaryOrange),
          )
        else ...[
          TextButton(
            onPressed: _pickImage,
            child: Text(_imagePath == null ? 'Escolher' : 'Trocar',
                style: const TextStyle(color: AppTheme.primaryOrange)),
          ),
          if (_imagePath != null)
            IconButton(
              onPressed: () => setState(() => _imagePath = null),
              icon: Icon(Icons.close,
                  size: 18,
                  color: AppTheme.mediumBrown.withValues(alpha: 0.6)),
              tooltip: 'Remover imagem',
            ),
        ],
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    bool autofocus = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: AppTheme.mediumBrown.withValues(alpha: 0.8)),
        filled: true,
        fillColor: AppTheme.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          borderSide: const BorderSide(
              color: AppTheme.primaryOrange, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
