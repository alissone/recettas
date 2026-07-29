import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/category_base.dart';
import '../models/habit.dart';

/// Color swatches, the same shape and palette as the category dialog in
/// edit_categories_screen.dart.
class ColorSwatchPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  final List<int> colors;

  const ColorSwatchPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.colors = CategoryBase.presetColors,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((c) {
        final isSelected = selected == c;
        return GestureDetector(
          onTap: () => onChanged(c),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(c),
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: AppTheme.darkBrown, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Color(c).withValues(alpha: 0.4),
                        blurRadius: 8,
                      )
                    ]
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Grid of the icons in [kHabitIcons], tinted with the habit's color.
/// Scrolls inside a fixed height so it can sit in a bottom sheet.
class HabitIconPicker extends StatelessWidget {
  final String selected;
  final int colorValue;
  final ValueChanged<String> onChanged;
  final double height;

  const HabitIconPicker({
    super.key,
    required this.selected,
    required this.colorValue,
    required this.onChanged,
    this.height = 132,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    final names = kHabitIcons.keys.toList();

    return SizedBox(
      height: height,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: names.length,
        itemBuilder: (context, index) {
          final name = names[index];
          final isSelected = name == selected;
          return GestureDetector(
            onTap: () => onChanged(name),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? color
                    : color.withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusXSmall),
              ),
              child: Icon(
                kHabitIcons[name],
                size: 20,
                color: isSelected ? Colors.white : color,
              ),
            ),
          );
        },
      ),
    );
  }
}
