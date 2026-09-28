import 'dart:convert';

import 'package:blue_sky/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Le manifeste de mise à jour, et les trois octets qui ont bloqué les
// postes en production.
//
// `Set-Content -Encoding UTF8` (PowerShell 5.1) préfixe le fichier d'un
// BOM. `jsonDecode` lève dessus. La vérification de mise à jour échouait
// donc à chaque passage, sans rien afficher — et le poste de Lubumbashi
// est resté en 0.0.19 pendant des jours alors que la 0.0.20 était
// publiée et téléchargeable.

void main() {
  const manifeste = '{"version":"0.0.20","download_url":"https://x/y.exe"}';

  group('Lecture du manifeste', () {
    test('un BOM en tête fait échouer jsonDecode — le piège', () {
      expect(() => jsonDecode('﻿$manifeste'), throwsFormatException,
          reason: "c'est bien le BOM qui cassait tout, pas autre chose");
    });

    test('sansBom le retire, et le manifeste se lit', () {
      final j = jsonDecode(sansBom('﻿$manifeste'));
      expect(j['version'], '0.0.20');
    });

    test('un manifeste propre traverse sans être abîmé', () {
      expect(sansBom(manifeste), manifeste);
      expect(jsonDecode(sansBom(manifeste))['version'], '0.0.20');
    });

    test('seul le PREMIER caractère est retiré', () {
      // Un BOM au milieu d'une chaîne est une donnée, pas un préfixe :
      // on n'y touche pas.
      const avecFeffInterne = '{"notes":"a﻿b"}';
      expect(sansBom(avecFeffInterne), avecFeffInterne);
    });

    test('une chaîne vide ne fait pas exploser la fonction', () {
      expect(sansBom(''), '');
    });
  });
}
