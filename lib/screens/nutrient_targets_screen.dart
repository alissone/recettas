import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/nutrient.dart';
import '../models/nutrient_recommendation.dart';
import '../services/supabase_service.dart';

/// Edits the daily nutrient targets the charts are measured against.
///
/// Targets live in a named set; the one a user follows is stored on their
/// profile. The seeded presets are shared and read-only, so the first
/// edit forks the active preset into a set the user owns and switches to
/// it - after that everything is editable in place.
class NutrientTargetsScreen extends StatefulWidget {
  const NutrientTargetsScreen({super.key});

  @override
  State<NutrientTargetsScreen> createState() =>
      _NutrientTargetsScreenState();
}

class _NutrientTargetsScreenState extends State<NutrientTargetsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  Map<NutrientId, Nutrient> _catalog = {};
  List<NutrientRecommendationSet> _sets = [];
  String? _activeSetId;
  Map<NutrientId, NutrientRecommendation> _targets = {};
  NutrientCategory _category = NutrientCategory.macronutrient;

  /// True when the active set changed, so the caller knows to reload.
  bool _dirty = false;

  NutrientRecommendationSet? get _activeSet =>
      _sets.where((s) => s.id == _activeSetId).firstOrNull;

  bool get _isEditable => _activeSet != null && !_activeSet!.isShared;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final catalogList = await SupabaseService.getNutrientCatalog();
      final sets = await SupabaseService.getRecommendationSets();

      String? activeSetId;
      try {
        final profile = await SupabaseService.getProfile();
        activeSetId = profile?['active_recommendation_set_id'];
      } catch (_) {}
      activeSetId ??= sets.where((s) => s.isShared).firstOrNull?.id;

      final targets = activeSetId == null
          ? <NutrientId, NutrientRecommendation>{}
          : {
              for (final r
                  in await SupabaseService.getRecommendations(activeSetId))
                r.nutrient: r,
            };

      if (!mounted) return;
      setState(() {
        _catalog = {for (final n in catalogList) n.id: n};
        _sets = sets;
        _activeSetId = activeSetId;
        _targets = targets;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao carregar: $e')));
      }
    }
  }

  Future<void> _reloadTargets() async {
    final setId = _activeSetId;
    if (setId == null) {
      setState(() => _targets = {});
      return;
    }
    final recommendations =
        await SupabaseService.getRecommendations(setId);
    if (!mounted) return;
    setState(() {
      _targets = {for (final r in recommendations) r.nutrient: r};
    });
  }

  /// Copies the active preset into a set the user owns, then follows it.
  /// Returns the new set id, or null if it failed.
  Future<String?> _forkActiveSet() async {
    setState(() => _isSaving = true);
    try {
      final source = _activeSet;
      final name = source == null
          ? 'Minhas metas'
          : 'Minhas metas (${source.name})';
      final newId = await SupabaseService.createRecommendationSet(
        name: name,
        description: source == null
            ? null
            : 'Cópia editável de "${source.name}".',
      );
      await SupabaseService.addRecommendations(
          newId, _targets.values.toList());
      await SupabaseService.setActiveRecommendationSet(newId);

      final sets = await SupabaseService.getRecommendationSets();
      if (!mounted) return null;
      setState(() {
        _sets = sets;
        _activeSetId = newId;
        _dirty = true;
      });
      await _reloadTargets();
      return newId;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao criar cópia: $e')));
      }
      return null;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Makes sure there is an editable set before writing a target.
  Future<String?> _ensureEditableSet() async {
    if (_isEditable) return _activeSetId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text('Criar metas próprias', style: AppTheme.headingMedium),
        content: Text(
          _activeSet == null
              ? 'Vamos criar um conjunto de metas seu para editar.'
              : '"${_activeSet!.name}" é um modelo compartilhado e não '
                  'pode ser alterado. Criar uma cópia sua para editar?',
          style: AppTheme.bodyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: TextStyle(color: AppTheme.mediumBrown)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Criar cópia'),
          ),
        ],
      ),
    );
    if (confirmed != true) return null;
    return _forkActiveSet();
  }

  Future<void> _editTarget(Nutrient nutrient) async {
    final setId = await _ensureEditableSet();
    if (setId == null || !mounted) return;

    final existing = _targets[nutrient.id];
    final unit = existing?.unit ?? nutrient.unit;
    final controller = TextEditingController(
      text: existing != null ? formatNutrientAmount(existing.amount) : '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text(nutrient.name, style: AppTheme.headingMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Meta por dia',
                suffixText: kNutrientUnitLabels[unit] ?? unit.name,
                filled: true,
                fillColor: AppTheme.white,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSmall),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('Deixe em branco para não acompanhar este nutriente.',
                style:
                    AppTheme.caption.copyWith(fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: TextStyle(color: AppTheme.mediumBrown)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;

    final text = result.trim().replaceAll(',', '.');
    final amount = double.tryParse(text);
    if (text.isNotEmpty && (amount == null || amount < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe um número válido.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (text.isEmpty) {
        await SupabaseService.deleteRecommendation(
            setId: setId, nutrient: nutrient.id);
      } else {
        await SupabaseService.upsertRecommendation(
          setId: setId,
          nutrient: nutrient.id,
          amount: amount!,
          unit: unit,
        );
      }
      _dirty = true;
      await _reloadTargets();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickSet() async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppTheme.creamBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text('Conjunto de metas', style: AppTheme.headingMedium),
        children: [
          for (final set in _sets)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, set.id),
              child: Row(
                children: [
                  Icon(
                    set.id == _activeSetId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: AppTheme.primaryOrange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(set.name, style: AppTheme.bodyText),
                  ),
                  if (set.isShared)
                    Text('modelo', style: AppTheme.caption),
                ],
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: Row(
              children: [
                Icon(
                  _activeSetId == null
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: AppTheme.primaryOrange,
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text('Sem metas', style: AppTheme.bodyText)),
              ],
            ),
          ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;

    final setId = chosen.isEmpty ? null : chosen;
    setState(() {
      _activeSetId = setId;
      _dirty = true;
    });
    try {
      await SupabaseService.setActiveRecommendationSet(setId);
      await _reloadTargets();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao trocar de conjunto: $e')));
      }
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final nutrients = _catalog.values
        .where((n) => n.category == _category)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _dirty);
      },
      child: Scaffold(
        backgroundColor: AppTheme.creamBackground,
        appBar: AppBar(
          title: const Text('Metas diárias'),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : _pickSet,
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Trocar de conjunto',
            ),
          ],
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryOrange))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildSetCard(),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in NutrientCategory.values)
                          _buildCategoryChip(category),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildNutrientList(nutrients),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSetCard() {
    final set = _activeSet;

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
              Expanded(
                child: Text(set?.name ?? 'Sem metas',
                    style: AppTheme.sectionTitle),
              ),
              if (set != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: set.isShared
                        ? AppTheme.mediumBrown.withValues(alpha: 0.12)
                        : AppTheme.primaryOrange.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusTiny),
                  ),
                  child: Text(
                    set.isShared ? 'Modelo' : 'Suas metas',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: set.isShared
                          ? AppTheme.mediumBrown
                          : AppTheme.primaryOrange,
                    ),
                  ),
                ),
            ],
          ),
          if (set?.description != null &&
              set!.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(set.description!,
                style:
                    AppTheme.caption.copyWith(fontWeight: FontWeight.w400)),
          ],
          const SizedBox(height: 10),
          Text(
            _isEditable
                ? 'Toque em um nutriente para definir a meta do dia.'
                : set == null
                    ? 'Escolha um modelo ou crie suas próprias metas.'
                    : 'Modelos são compartilhados e não podem ser '
                        'alterados. Crie uma cópia para editar.',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
          ),
          if (!_isEditable) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _forkActiveSet,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(set == null
                    ? 'Criar minhas metas'
                    : 'Criar cópia editável'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryOrange,
                  side: BorderSide(color: AppTheme.borderOrange),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryChip(NutrientCategory category) {
    final isSelected = category == _category;
    final count = _catalog.values
        .where((n) => n.category == category && _targets.containsKey(n.id))
        .length;

    return GestureDetector(
      onTap: () => setState(() => _category = category),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryOrange
              : AppTheme.primaryOrange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
        ),
        child: Text(
          count > 0
              ? '${kNutrientCategoryLabels[category]} · $count'
              : '${kNutrientCategoryLabels[category]}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.primaryOrange,
          ),
        ),
      ),
    );
  }

  Widget _buildNutrientList(List<Nutrient> nutrients) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          for (final nutrient in nutrients)
            _buildNutrientRow(nutrient),
        ],
      ),
    );
  }

  Widget _buildNutrientRow(Nutrient nutrient) {
    final target = _targets[nutrient.id];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSaving ? null : () => _editTarget(nutrient),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(nutrient.name,
                    style: target != null
                        ? AppTheme.valueBold
                        : AppTheme.bodyText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 12),
              Text(
                target != null
                    ? '${formatNutrientAmount(target.amount)} '
                        '${kNutrientUnitLabels[target.unit] ?? target.unit.name}'
                    : '—',
                style: target != null
                    ? AppTheme.valueBold.copyWith(
                        color: AppTheme.primaryOrange)
                    : AppTheme.caption,
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right,
                  size: 18,
                  color: AppTheme.mediumBrown.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
