import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/nutrient.dart' show formatQuantity;
import '../services/supabase_service.dart';

/// Full-screen intake form for everything a future RMR/TDEE estimate will
/// need: body stats, goal, and training volume. It only collects and saves
/// data for now - nothing here computes an estimate yet.
///
/// Replaces the old inline "height and weight" dialog on Profile; height
/// and weight are still here, and saving a changed weight also logs a
/// weight-history entry for the Nutrition screen's weight chart.
class BodyProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;

  const BodyProfileScreen({super.key, this.profile});

  @override
  State<BodyProfileScreen> createState() => _BodyProfileScreenState();
}

class _BodyProfileScreenState extends State<BodyProfileScreen> {
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _liftDaysController;
  late final TextEditingController _liftMinutesController;
  late final TextEditingController _cardioDaysController;
  late final TextEditingController _cardioTypeController;
  late final TextEditingController _cardioMinutesController;
  late final TextEditingController _stepsController;
  late final TextEditingController _bodyFatController;
  late final TextEditingController _cardioHeartRateController;

  String? _sex;
  String _goal = 'maintain';
  String _goalRate = 'moderate';
  String? _occupationActivity;
  String? _cardioIntensity;
  String? _liftingIntensity;

  double? _initialWeight;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _initialWeight = _dbl(p?['weight_kg']);

    _ageController = TextEditingController(text: _intText(p?['age']));
    _heightController =
        TextEditingController(text: _dblText(p?['height_cm']));
    _weightController = TextEditingController(text: _dblText(p?['weight_kg']));
    _liftDaysController =
        TextEditingController(text: _intText(p?['weightlifting_days_per_week']));
    _liftMinutesController = TextEditingController(
        text: _intText(p?['weightlifting_minutes_per_session']));
    _cardioDaysController =
        TextEditingController(text: _intText(p?['cardio_days_per_week']));
    _cardioTypeController =
        TextEditingController(text: p?['cardio_type']?.toString() ?? '');
    _cardioMinutesController = TextEditingController(
        text: _intText(p?['cardio_minutes_per_session']));
    _stepsController =
        TextEditingController(text: _intText(p?['average_daily_steps']));
    _bodyFatController =
        TextEditingController(text: _dblText(p?['body_fat_percent']));
    _cardioHeartRateController =
        TextEditingController(text: _intText(p?['cardio_heart_rate']));

    _sex = p?['sex'];
    _goal = p?['goal'] ?? 'maintain';
    _goalRate = p?['goal_rate'] ?? 'moderate';
    _occupationActivity = p?['occupation_activity'];
    _cardioIntensity = p?['cardio_intensity'];
    _liftingIntensity = p?['lifting_intensity'];
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _liftDaysController.dispose();
    _liftMinutesController.dispose();
    _cardioDaysController.dispose();
    _cardioTypeController.dispose();
    _cardioMinutesController.dispose();
    _stepsController.dispose();
    _bodyFatController.dispose();
    _cardioHeartRateController.dispose();
    super.dispose();
  }

  static double? _dbl(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());
  static String _dblText(dynamic v) {
    final d = _dbl(v);
    return d != null ? formatQuantity(d) : '';
  }

  static int? _int(dynamic v) =>
      v == null ? null : int.tryParse(v.toString());
  static String _intText(dynamic v) {
    final i = _int(v);
    return i != null ? i.toString() : '';
  }

  double? _parseDouble(String text) {
    final t = text.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  int? _parseInt(String text) {
    final t = text.trim();
    return t.isEmpty ? null : int.tryParse(t);
  }

  Future<void> _save() async {
    final height = _parseDouble(_heightController.text);
    final weight = _parseDouble(_weightController.text);
    final cardioType = _cardioTypeController.text.trim();

    setState(() => _isSaving = true);
    try {
      await SupabaseService.updateProfile(
        heightCm: height,
        weightKg: weight,
        sex: _sex,
        age: _parseInt(_ageController.text),
        goal: _goal,
        goalRate: _goal == 'maintain' ? null : _goalRate,
        weightliftingDaysPerWeek: _parseInt(_liftDaysController.text),
        weightliftingMinutesPerSession:
            _parseInt(_liftMinutesController.text),
        cardioDaysPerWeek: _parseInt(_cardioDaysController.text),
        cardioType: cardioType.isEmpty ? null : cardioType,
        cardioMinutesPerSession: _parseInt(_cardioMinutesController.text),
        averageDailySteps: _parseInt(_stepsController.text),
        occupationActivity: _occupationActivity,
        bodyFatPercent: _parseDouble(_bodyFatController.text),
        cardioIntensity: _cardioIntensity,
        cardioHeartRate: _parseInt(_cardioHeartRateController.text),
        liftingIntensity: _liftingIntensity,
      );
      // Only a real change becomes a check-in - resaving the form with the
      // same weight shouldn't add noise to the history chart.
      if (weight != null && weight != _initialWeight) {
        await SupabaseService.addWeightEntry(weight);
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
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        title: const Text('Perfil físico'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              _isSaving ? 'Salvando...' : 'Salvar',
              style: const TextStyle(
                  color: AppTheme.primaryOrange, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Usado futuramente para estimar sua taxa metabólica basal '
              '(RMR). Pode preencher aos poucos - nada aqui é obrigatório '
              'para salvar.',
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 24),
            Text('Necessário', style: AppTheme.sectionTitle),
            const SizedBox(height: 16),
            _buildSegmented<String>(
              label: 'Sexo',
              value: _sex,
              options: const [('male', 'Masculino'), ('female', 'Feminino')],
              onChanged: (v) => setState(() => _sex = v),
            ),
            _buildNumberField(
                controller: _ageController, label: 'Idade', suffix: 'anos'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                      controller: _heightController,
                      label: 'Altura',
                      suffix: 'cm',
                      decimal: true),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberField(
                      controller: _weightController,
                      label: 'Peso',
                      suffix: 'kg',
                      decimal: true),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSegmented<String>(
              label: 'Objetivo',
              value: _goal,
              options: const [
                ('maintain', 'Manter'),
                ('lose', 'Perder'),
                ('gain', 'Ganhar'),
              ],
              onChanged: (v) => setState(() => _goal = v),
            ),
            if (_goal != 'maintain')
              _buildSegmented<String>(
                label: 'Ritmo desejado',
                value: _goalRate,
                options: const [
                  ('slow', 'Lento'),
                  ('moderate', 'Moderado'),
                  ('fast', 'Rápido'),
                ],
                onChanged: (v) => setState(() => _goalRate = v),
              ),
            Text('Musculação',
                style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                      controller: _liftDaysController,
                      label: 'Dias/semana',
                      suffix: 'dias'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberField(
                      controller: _liftMinutesController,
                      label: 'Min/sessão',
                      suffix: 'min'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Cardio',
                style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                      controller: _cardioDaysController,
                      label: 'Dias/semana',
                      suffix: 'dias'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberField(
                      controller: _cardioMinutesController,
                      label: 'Min/sessão',
                      suffix: 'min'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(
                controller: _cardioTypeController,
                label: 'Tipo (corrida, bike, natação...)'),
            const SizedBox(height: 20),
            _buildNumberField(
                controller: _stepsController,
                label: 'Passos diários médios (se souber)',
                suffix: 'passos'),
            const SizedBox(height: 32),
            Text('Muito útil', style: AppTheme.sectionTitle),
            const SizedBox(height: 16),
            _buildSegmented<String>(
              label: 'Atividade no trabalho',
              value: _occupationActivity,
              options: const [
                ('sedentary', 'Sentado'),
                ('standing', 'Em pé'),
                ('physical', 'Físico'),
              ],
              onChanged: (v) => setState(() => _occupationActivity = v),
            ),
            _buildNumberField(
                controller: _bodyFatController,
                label: '% de gordura corporal aproximada',
                suffix: '%',
                decimal: true),
            const SizedBox(height: 20),
            _buildSegmented<String>(
              label: 'Intensidade do cardio',
              value: _cardioIntensity,
              options: const [
                ('easy', 'Leve'),
                ('moderate', 'Moderado'),
                ('hard', 'Intenso'),
              ],
              onChanged: (v) => setState(() => _cardioIntensity = v),
            ),
            _buildNumberField(
                controller: _cardioHeartRateController,
                label: 'Ou frequência cardíaca média, se acompanha',
                suffix: 'bpm'),
            const SizedBox(height: 20),
            _buildSegmented<String>(
              label: 'Intensidade da musculação',
              value: _liftingIntensity,
              options: const [
                ('light', 'Leve'),
                ('moderate', 'Moderada'),
                ('hard', 'Intensa'),
              ],
              onChanged: (v) => setState(() => _liftingIntensity = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmented<T>({
    required String label,
    required T? value,
    required List<(T, String)> options,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<T>(
            segments: [
              for (final o in options)
                ButtonSegment(value: o.$1, label: Text(o.$2)),
            ],
            selected: value != null ? {value} : {},
            emptySelectionAllowed: value == null,
            onSelectionChanged: (s) => onChanged(s.first),
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor:
                  AppTheme.primaryOrange.withValues(alpha: 0.15),
              selectedForegroundColor: AppTheme.primaryOrange,
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: AppTheme.borderOrange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    String? suffix,
    bool decimal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
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
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
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
      ),
    );
  }
}
