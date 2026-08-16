import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/food.dart';
import '../models/nutrient.dart';

/// Search-and-pick over the food catalog, as a bottom sheet. Returns the
/// chosen food, or null when it was dismissed.
///
/// Both the recipe editor and the package editor build on the catalog
/// that is already there rather than letting a user type a new food, so
/// every nutrient value in the app keeps coming from a catalogued row.
Future<Food?> showFoodPicker(
  BuildContext context,
  List<Food> foods, {
  String title = 'Escolher ingrediente',

  /// Already used by whatever is being edited; shown greyed out so it is
  /// obvious why tapping does nothing.
  Set<String> disabledIds = const {},
}) {
  return showModalBottomSheet<Food>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.creamBackground,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
    ),
    builder: (_) => _FoodPickerSheet(
      foods: foods,
      title: title,
      disabledIds: disabledIds,
    ),
  );
}

class _FoodPickerSheet extends StatefulWidget {
  final List<Food> foods;
  final String title;
  final Set<String> disabledIds;

  const _FoodPickerSheet({
    required this.foods,
    required this.title,
    required this.disabledIds,
  });

  @override
  State<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<_FoodPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final matches = query.isEmpty
        ? widget.foods.take(30).toList()
        : widget.foods
            .where((f) => f.label.toLowerCase().contains(query))
            .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: AppTheme.headingMedium),
          const SizedBox(height: 16),
          TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Buscar alimento',
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
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: matches.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('Nenhum alimento encontrado.',
                        style: AppTheme.caption
                            .copyWith(fontWeight: FontWeight.w400)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final food = matches[index];
                      final disabled =
                          widget.disabledIds.contains(food.id);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        enabled: !disabled,
                        title: Text(food.label,
                            style: disabled
                                ? AppTheme.bodyText.copyWith(
                                    color: AppTheme.mediumBrown
                                        .withValues(alpha: 0.5))
                                : AppTheme.bodyText),
                        subtitle: Text(
                          disabled
                              ? 'Já está na lista'
                              : '${food.get(NutrientId.calories).round()} kcal '
                                  'por ${formatNutrientAmount(food.baseAmount)} '
                                  '${food.baseUnit}',
                          style: AppTheme.caption,
                        ),
                        onTap: () => Navigator.pop(context, food),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
