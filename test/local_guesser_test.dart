import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/services/local_guesser.dart';
import 'package:recettas/widgets/local_field.dart';

void main() {
  group('LocalGuesser.parseCoords', () {
    test('parses the default "lat, lng" string', () {
      final coords = LocalGuesser.parseCoords('-5.816108668781542, -46.1304306899312');
      expect(coords, isNotNull);
      expect(coords!.$1, closeTo(-5.816108668781542, 1e-12));
      expect(coords.$2, closeTo(-46.1304306899312, 1e-12));
    });

    test('tolerates missing space after the comma', () {
      expect(LocalGuesser.parseCoords('-5.8,-46.1'), (-5.8, -46.1));
    });

    test('rejects malformed strings', () {
      expect(LocalGuesser.parseCoords(''), isNull);
      expect(LocalGuesser.parseCoords('-5.8'), isNull);
      expect(LocalGuesser.parseCoords('-5.8, abc'), isNull);
      expect(LocalGuesser.parseCoords('-5.8, -46.1, 3'), isNull);
    });
  });

  test('every frequent place has parseable or empty coordinates', () {
    for (final entry in kFrequentLocalCoords.entries) {
      // "" marks a place whose coordinates weren't collected yet; it
      // is skipped by the guesser but must never be a typo like "-5.8".
      if (entry.value.isEmpty) continue;
      expect(LocalGuesser.parseCoords(entry.value), isNotNull,
          reason: '${entry.key} has malformed coords "${entry.value}"');
    }
  });

  group('LocalGuesser.nearestWithin', () {
    test('suggests the place the user is standing at', () {
      // Exactly the coordinates of Queiroz.
      expect(
        LocalGuesser.nearestWithin(-5.816108668781542, -46.1304306899312),
        'Queiroz',
      );
    });

    test('picks the nearest when several places are within 50 m', () {
      // ~22 m from Farmacia Ultra Popular and ~43 m from Lanche
      // Vitoria: both in range, the closer one wins.
      expect(
        LocalGuesser.nearestWithin(-5.8156410, -46.1346870),
        'Farmacia Ultra Popular',
      );
      // Same street, now ~22 m from Lanche Vitoria and ~43 m from
      // Farmacia Ultra Popular.
      expect(
        LocalGuesser.nearestWithin(-5.8154462, -46.1347000),
        'Lanche Vitoria',
      );
    });

    test('suggests nothing when no place is in range', () {
      expect(LocalGuesser.nearestWithin(-5.9, -46.2), isNull);
    });
  });
}
