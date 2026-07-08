import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Most used places offered in the Local dropdown.
const List<String> kFrequentLocals = [
  'Queiroz',
  'Peixoto',
  'Camino',
  'Farmacia Ultra Popular',
  'Hiper+',
  'CTFalcao',
  'Torres Construcoes',
  'Larissa Construcoes',
  'Goncalves Construcoes',
  'Lanche Vitoria',
  'Farmacia Pague Menos',
  'Pix Carol',
  'Vivo',
  'Unigrande',
];

/// Split "Local" input: a dropdown of most-used places on the left and
/// the usual free-text field on the right. Picking a place clears the
/// typed text; tapping the text field resets the dropdown to empty.
///
/// On save the caller should prefer [preset] over the controller text.
class LocalField extends StatelessWidget {
  final String? preset;
  final ValueChanged<String?> onPresetChanged;
  final TextEditingController controller;
  final InputDecoration Function(String label) decorationBuilder;

  const LocalField({
    super.key,
    required this.preset,
    required this.onPresetChanged,
    required this.controller,
    required this.decorationBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InputDecorator(
            decoration: decorationBuilder('Local'),
            isEmpty: preset == null,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: preset,
                isExpanded: true,
                isDense: true,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSmall),
                dropdownColor: AppTheme.white,
                style: AppTheme.bodyText,
                items: [
                  for (final place in kFrequentLocals)
                    DropdownMenuItem(
                      value: place,
                      child: Text(
                        place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) {
                  controller.clear();
                  onPresetChanged(v);
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: decorationBuilder('Outro local'),
            onTap: () {
              if (preset != null) onPresetChanged(null);
            },
          ),
        ),
      ],
    );
  }
}
