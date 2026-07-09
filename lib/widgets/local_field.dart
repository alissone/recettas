import 'package:flutter/material.dart';

import '../app_theme.dart';


/// Most used places offered in the Local dropdown, mapped to their
/// "lat, lng" coordinates (parsed at runtime by LocalGuesser). A place
/// is suggested automatically when the phone is within
/// [kLocalSuggestionRadiusMeters] of it.
const Map<String, String> kFrequentLocalCoords = {
  'CTFalcao': "-5.816143323810006, -46.13594036343797",
  'Camino': "-5.828665627844275, -46.17171831046831",
  'Farmacia Pague Menos': "-5.820053795256173, -46.15830968792096",
  'Farmacia Ultra Popular': "-5.815835982103011, -46.13467805580731",
  'Goncalves Construcoes': "-5.815672296961361, -46.13344080325571",
  'Hiper+': "-5.816553391764024, -46.13664354359778",
  'Lanche Vitoria': "-5.815251211305602, -46.13470422817626",
  'Larissa Construcoes': "-5.815361427838658, -46.13393902358022",
  "Mello" : "-5.8150207341679945, -46.134444273686086",
  'Peixoto': "-5.815019069929221, -46.13210085123408",
  'Pix Carol': "",
  'Queiroz': '-5.816108668781542, -46.1304306899312',
  'Torres Construcoes': "-5.815773649672106, -46.13380438598688",
  'Unigrande': "-5.817420811842902, -46.15689816223729",
  'Vivo': "",
};

const double kLocalSuggestionRadiusMeters = 50;

/// Most used places offered in the Local dropdown.
List<String> get kFrequentLocals =>
    kFrequentLocalCoords.keys.toList(growable: false);

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
