import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Garde-fous du soin de l'interface.
//
// Ces règles ont été appliquées une fois à la main. Sans test, elles se
// déferont : quelqu'un recopiera une couleur en dur un vendredi soir, ou
// ajoutera un emoji dans un libellé. Un test qui lit le code source les
// rend permanentes — et signale la faute au moment où elle est écrite,
// pas trois mois plus tard sur une capture d'écran.
//
// Chaque règle a une exception documentée plutôt qu'aucune exception :
// une règle sans échappatoire finit contournée.

Iterable<File> _sources() sync* {
  for (final e in Directory('lib').listSync(recursive: true)) {
    if (e is! File || !e.path.endsWith('.dart')) continue;
    if (e.path.endsWith('.g.dart')) continue; // code généré
    yield e;
  }
}

/// Retire commentaires de ligne et de doc : seul ce qui est AFFICHÉ
/// compte. Un `⚠️` dans une explication destinée au développeur est
/// utile ; le même dans un libellé ne l'est pas.
String _sansCommentaires(String source) =>
    source.split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');

String _relatif(File f) => f.path.replaceAll(r'\', '/').split('lib/').last;

void main() {
  group('Une seule charte de couleurs', () {
    test('aucune couleur écrite en dur hors de tokens.dart', () {
      // Les fautes trouvées le 16 septembre 2026 : un bleu Material
      // (0xFF3D8BFD) sur l'emplacement Restaurant, le statut Nettoyage
      // et le rôle Gérant ; un violet (0xFF8E44AD) sur le rôle Réception
      // et dans le tableau de bord web. Aucun des deux n'appartenait à
      // la charte, et ils juraient sur les écrans les plus regardés.
      final fautifs = <String>[];
      for (final f in _sources()) {
        if (f.path.endsWith('tokens.dart')) continue;
        final src = _sansCommentaires(f.readAsStringSync());
        for (final m in RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)').allMatches(src)) {
          fautifs.add('${_relatif(f)} : ${m.group(0)}');
        }
      }
      expect(fautifs, isEmpty,
          reason: 'Utilise BsColors. Une couleur définie sur place '
              'échappe au thème et au mode sombre.');
    });
  });

  group('Pas d\'emoji dans ce que les gens lisent', () {
    test('aucun emoji dans un libellé affiché', () {
      // Décision produit : « c'est des adultes ». Retirés : la loupe du
      // champ de recherche, le confetti des dettes soldées, le téléphone
      // des réservations, et deux ⚠ dans des PDF — sur un document
      // imprimé, un glyphe absent de la police devient un carré vide.
      //
      // Restent autorisés : les commentaires de code et les traces
      // console. Les flèches typographiques (« FC → USD ») ne sont pas
      // des emoji et ne sont pas visées.
      final emoji =
          RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true);
      final fautifs = <String>[];
      for (final f in _sources()) {
        final lignes = f.readAsStringSync().split('\n');
        for (var i = 0; i < lignes.length; i++) {
          final l = lignes[i];
          if (l.trimLeft().startsWith('//')) continue;
          // Exception assumée : une trace console s'adresse au
          // développeur, jamais à la réception. Un ⚠ y est utile pour
          // repérer la ligne dans un flot de logs.
          if (l.contains('debugPrint(')) continue;
          if (emoji.hasMatch(l)) {
            fautifs.add('${_relatif(f)}:${i + 1}');
          }
        }
      }
      expect(fautifs, isEmpty,
          reason: 'Utilise une icône (Icons.*_outlined) : même famille '
              'que le reste, et une couleur qu\'on maîtrise.');
    });
  });

  group('Une seule famille d\'icônes', () {
    test('toutes les icônes sont en style outlined', () {
      // 43 icônes `_outlined` contre une seule `_rounded` : l'exception
      // ne se nomme pas, mais elle se sent.
      final fautifs = <String>[];
      for (final f in _sources()) {
        final src = _sansCommentaires(f.readAsStringSync());
        for (final m
            in RegExp(r'Icons\.[a-z_0-9]+_(rounded|sharp)').allMatches(src)) {
          fautifs.add('${_relatif(f)} : ${m.group(0)}');
        }
      }
      expect(fautifs, isEmpty, reason: 'Prends la variante _outlined.');
    });
  });

  group('Hauteurs de contrôles', () {
    test('aucune hauteur de bouton posée à la main', () {
      // Trois valeurs coexistaient pour le même objet : 30 px dans
      // Stock, 32 px dans Historique. Elles passent par BsControl.
      final fautifs = <String>[];
      for (final f in _sources()) {
        final src = _sansCommentaires(f.readAsStringSync());
        for (final m in RegExp(r'minimumSize: const Size\(0, [0-9]+\)')
            .allMatches(src)) {
          fautifs.add('${_relatif(f)} : ${m.group(0)}');
        }
      }
      expect(fautifs, isEmpty,
          reason: 'Utilise BsControl.compact / normal / primary.');
    });
  });
}
