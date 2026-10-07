import 'package:blue_sky/services/mirror_pull_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Le 7 octobre 2026, une erreur permanente relançait la synchronisation
// complète toutes les quinze secondes : une quarantaine d'échecs toutes les
// dix minutes. Une synchronisation ratée se retente désormais de plus en
// plus loin, jusqu'à l'intervalle normal de dix minutes.

void main() {
  Duration d(int n) => MirrorPullService.delaiAvantNouvelEssai(n);

  test('une coupure passagère est rattrapée vite', () {
    expect(d(1), const Duration(seconds: 15));
    expect(d(2), const Duration(seconds: 30));
    expect(d(3), const Duration(minutes: 1));
  });

  test('une erreur qui dure ne martèle plus le serveur', () {
    expect(d(5), const Duration(minutes: 4));
    expect(d(6), const Duration(minutes: 8));
    expect(d(7), const Duration(minutes: 10), reason: 'plafond');
    expect(d(50), const Duration(minutes: 10));
  });

  test('aucun échec : aucune attente', () {
    expect(d(0), Duration.zero);
  });
}
