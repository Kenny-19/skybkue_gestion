import 'package:blue_sky/services/synchro_par_difference.dart';
import 'package:flutter_test/flutter_test.dart';

// Toutes les quinze secondes, chaque poste relisait tout le serveur :
// 111 Ko par tour, ~630 Mo par jour et par poste. Il ne relit plus que ce
// qui a changé.

class _Serveur {
  Map<String, dynamic>? versions = {
    'rooms': {'max': '2026-11-17T08:00:00+00:00', 'nb': 22},
    'clients': '2026-11-17T08:00:00+00:00',
    'payers': '2026-11-16T08:00:00+00:00',
    'articles': '2026-11-17T07:00:00+00:00',
    'stays': '2026-11-15T08:00:00+00:00',
  };
  final lus = <(String, DateTime?)>[];
  var toutRelu = 0;
  final enPanne = <String>{};

  SynchroParDifference synchro() => SynchroParDifference(
        lireVersions: () async => versions,
        toutRelire: () async => toutRelu++,
        tirer: (table, {depuis}) async {
          if (enPanne.contains(table)) throw Exception('coupure');
          lus.add((table, depuis));
        },
      );
}

void main() {
  final t0 = DateTime.utc(2026, 11, 17, 10);

  test('premier tour : tout est relu en entier, payeurs avant chambres',
      () async {
    final s = _Serveur();
    await s.synchro().tour(maintenant: t0);
    expect(s.lus.map((l) => l.$1),
        ['payers', 'clients', 'articles', 'rooms', 'stays']);
    expect(s.lus.every((l) => l.$2 == null), isTrue, reason: 'en entier');
  });

  test('rien n\'a changé : rien n\'est relu', () async {
    final s = _Serveur();
    final sync = s.synchro();
    await sync.tour(maintenant: t0);
    s.lus.clear();
    for (var i = 1; i <= 200; i++) {
      await sync.tour(maintenant: t0.add(Duration(seconds: 15 * i)));
    }
    expect(s.lus, isEmpty, reason: '50 minutes de calme : zéro relecture');
  });

  test(
      'une table qui change : elle seule, depuis le dernier passage '
      '(moins deux minutes)', () async {
    final s = _Serveur();
    final sync = s.synchro();
    await sync.tour(maintenant: t0);
    s.lus.clear();
    s.versions!['clients'] = '2026-11-17T09:30:00+00:00';
    await sync.tour(maintenant: t0.add(const Duration(seconds: 15)));
    expect(s.lus, hasLength(1));
    expect(s.lus.single.$1, 'clients');
    expect(s.lus.single.$2, DateTime.utc(2026, 11, 17, 7, 58),
        reason: 'curseur précédent (8 h 00) reculé de deux minutes');
  });

  test('une chambre supprimée (même date, une ligne de moins) est vue',
      () async {
    final s = _Serveur();
    final sync = s.synchro();
    await sync.tour(maintenant: t0);
    s.lus.clear();
    s.versions!['rooms'] = {'max': '2026-11-17T08:00:00+00:00', 'nb': 21};
    await sync.tour(maintenant: t0.add(const Duration(seconds: 15)));
    expect(s.lus.map((l) => l.$1), ['rooms']);
  });

  test('une lecture qui échoue est retentée, depuis le même point', () async {
    final s = _Serveur();
    final sync = s.synchro();
    await sync.tour(maintenant: t0);
    s.lus.clear();
    s.versions!['stays'] = '2026-11-17T09:00:00+00:00';
    s.enPanne.add('stays');
    await sync.tour(maintenant: t0.add(const Duration(seconds: 15)));
    expect(s.lus, isEmpty);
    s.enPanne.clear();
    await sync.tour(maintenant: t0.add(const Duration(seconds: 30)));
    expect(s.lus.single.$1, 'stays');
    expect(s.lus.single.$2, DateTime.utc(2026, 11, 15, 7, 58),
        reason: 'repart de l\'ancien curseur : rien de perdu');
  });

  test('une fois par heure, tout est relu en entier (filet)', () async {
    final s = _Serveur();
    final sync = s.synchro();
    await sync.tour(maintenant: t0);
    s.lus.clear();
    await sync.tour(maintenant: t0.add(const Duration(minutes: 59)));
    expect(s.lus, isEmpty);
    await sync.tour(maintenant: t0.add(const Duration(hours: 1)));
    expect(s.lus, hasLength(5));
    expect(s.lus.every((l) => l.$2 == null), isTrue);
  });

  test('serveur sans la fonction (SQL pas passé) : tout relire, comme avant',
      () async {
    final s = _Serveur()..versions = null;
    await s.synchro().tour(maintenant: t0);
    expect(s.toutRelu, 1);
    expect(s.lus, isEmpty);
  });

  test('serveur injoignable : le tour lève, l\'appelant le compte en coupure',
      () async {
    final sync = SynchroParDifference(
      lireVersions: () async => throw Exception('hors ligne'),
      toutRelire: () async {},
      tirer: (t, {depuis}) async {},
    );
    await expectLater(sync.tour(maintenant: t0), throwsException);
  });
}
