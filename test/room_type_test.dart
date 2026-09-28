import 'package:blue_sky/core/room_type.dart';
import 'package:flutter_test/flutter_test.dart';

// Les cas viennent de la vraie base de production : `standard` ×14,
// `Standard`, `STANDARD`, `SIMPLE`, `APPARTEMENT`, et `230000`.

void main() {
  group('Unification de la casse', () {
    test('les trois écritures de standard donnent la même chose', () {
      expect(normalizeRoomType('standard'), 'Standard');
      expect(normalizeRoomType('Standard'), 'Standard');
      expect(normalizeRoomType('STANDARD'), 'Standard');
    });

    test('les autres types de la base sont normalisés pareil', () {
      expect(normalizeRoomType('SIMPLE'), 'Simple');
      expect(normalizeRoomType('APPARTEMENT'), 'Appartement');
    });

    test('les espaces superflus disparaissent', () {
      expect(normalizeRoomType('  suite   junior '), 'Suite junior');
    });

    test('casse française : majuscule au premier mot seulement', () {
      // « Suite Junior » serait une capitalisation anglaise.
      expect(normalizeRoomType('SUITE JUNIOR'), 'Suite junior');
    });

    test('un sigle court reste en majuscules', () {
      // « Vip » serait une faute, pas une normalisation.
      expect(normalizeRoomType('VIP'), 'VIP');
      expect(normalizeRoomType('chambre VIP'), 'Chambre VIP');
    });

    test('normaliser deux fois ne change plus rien', () {
      for (final t in ['standard', 'SIMPLE', 'suite  junior', 'VIP']) {
        final une = normalizeRoomType(t)!;
        expect(normalizeRoomType(une), une, reason: t);
      }
    });
  });

  group('Un prix n\'est pas un type', () {
    test('le cas réel de la chambre 19', () {
      expect(normalizeRoomType('230000'), isNull);
      expect(looksLikePrice('230000'), true);
    });

    test('les écritures avec séparateurs ou devise aussi', () {
      for (final p in [
        '230 000',
        '230.000',
        '230,000',
        '230000 FC',
        '299 000 FC'
      ]) {
        expect(looksLikePrice(p), true, reason: p);
        expect(normalizeRoomType(p), isNull, reason: p);
      }
    });

    test('un vrai type contenant un chiffre reste un type', () {
      // Sinon « Suite 2 » ou « T2 » seraient effacés à tort.
      expect(looksLikePrice('Suite 2'), false);
      expect(normalizeRoomType('suite 2'), 'Suite 2');
      expect(looksLikePrice('T2'), false);
    });

    test('un champ vide ne produit pas un type inventé', () {
      expect(normalizeRoomType(''), isNull);
      expect(normalizeRoomType('   '), isNull);
    });
  });

  group('Valeur de repli', () {
    test('elle est elle-même déjà normalisée', () {
      expect(normalizeRoomType(kTypeChambreParDefaut), kTypeChambreParDefaut);
    });
  });
}
