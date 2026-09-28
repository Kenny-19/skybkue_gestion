import 'dart:convert';
import 'dart:io';

import '../core/cloud_config.dart';

/// Une source d'heure interrogeable en ligne.
///
/// Pourquoi plusieurs
/// ------------------
/// Parce qu'une seule ne suffit pas, et pas pour la raison qu'on croit.
/// Le risque n'est pas qu'une source tombe — c'est qu'elle réponde, avec
/// une heure fausse. Sondage du 21 septembre 2026 depuis le poste :
/// `worldtimeapi.org` ne répondait pas du tout, et `timeapi.io` a rendu
/// une heure **avancée de quatre heures** tout en ayant l'air parfaite.
/// Une source unique mal choisie aurait déplacé toutes les ventes, sans
/// que rien ne le signale.
///
/// Trois sources indépendantes qui s'accordent à la seconde valent mieux
/// qu'une seule qui affirme.
class SourceEnLigne {
  const SourceEnLigne({
    required this.nom,
    required this.uri,
    required this.lire,
    this.autorite = false,
  });

  final String nom;
  final Uri uri;

  /// Extrait l'instant de la réponse. Null si elle est inexploitable.
  final DateTime? Function(HttpClientResponse, String corps) lire;

  /// Vrai pour la source qui FAIT FOI.
  ///
  /// C'est Supabase, et le choix n'est pas anodin : c'est son horloge
  /// qui pose les `synced_at` et qui date tout côté serveur. Une source
  /// externe peut être plus juste dans l'absolu et pourtant désaccordée
  /// avec elle — on réintroduirait alors exactement le décalage qu'on
  /// vient d'éliminer. Les autres servent de secours et de témoin.
  final bool autorite;
}

/// Les sources retenues, dans l'ordre où on les interroge.
///
/// Toutes rendent l'heure dans un en-tête HTTP `Date` ou un format
/// trivial : pas de JSON à faire confiance, pas de champ qui change de
/// sens d'une version d'API à l'autre.
List<SourceEnLigne> sourcesHeure() => [
      if (CloudConfig.isConfigured)
        SourceEnLigne(
          nom: 'Supabase',
          uri: Uri.parse('${CloudConfig.supabaseUrl}/rest/v1/'),
          autorite: true,
          lire: _enteteDate,
        ),
      // Cloudflare rend un horodatage à la fraction de seconde, là où un
      // en-tête HTTP s'arrête à la seconde.
      SourceEnLigne(
        nom: 'Cloudflare',
        uri: Uri.parse('https://cloudflare.com/cdn-cgi/trace'),
        lire: (_, corps) {
          for (final ligne in const LineSplitter().convert(corps)) {
            if (!ligne.startsWith('ts=')) continue;
            final s = double.tryParse(ligne.substring(3));
            if (s == null) return null;
            return DateTime.fromMillisecondsSinceEpoch((s * 1000).round(),
                isUtc: true);
          }
          return null;
        },
      ),
      // 204 sans corps : la réponse la plus légère qui porte une date.
      SourceEnLigne(
        nom: 'Google',
        uri: Uri.parse('https://www.google.com/generate_204'),
        lire: _enteteDate,
      ),
    ];

/// L'en-tête `Date`, toujours en GMT, à la seconde près. Cette
/// résolution suffit : on traque des erreurs de fuseau, qui se comptent
/// en heures.
DateTime? _enteteDate(HttpClientResponse r, String _) {
  final d = r.headers.value(HttpHeaders.dateHeader);
  return d == null ? null : HttpDate.parse(d);
}

/// Ce qu'une interrogation rapporte.
class MesureHeure {
  const MesureHeure({
    required this.source,
    required this.heure,
    required this.trajet,
    required this.horlogePoste,
  });

  final SourceEnLigne source;

  /// L'instant lu, tel que la source l'a annoncé.
  final DateTime heure;

  /// L'aller-retour complet. La moitié est à ajouter : l'heure a été
  /// écrite quelque part au milieu du trajet.
  final Duration trajet;

  /// Ce que l'horloge du poste affichait au moment de cette mesure.
  ///
  /// Sert de repère commun. Deux sources interrogées à cinq secondes
  /// d'intervalle annoncent forcément deux instants différents — les
  /// comparer directement ferait passer ces cinq secondes pour un
  /// désaccord d'horloge. Leurs DÉCALAGES par rapport au poste, eux,
  /// restent comparables : l'horloge du poste avance peut-être de deux
  /// heures, mais elle avance régulièrement.
  final DateTime horlogePoste;

  DateTime get instantCorrige => heure.toUtc().add(trajet ~/ 2);

  /// De combien le poste avance sur cette source.
  Duration get decalagePoste => horlogePoste.toUtc().difference(instantCorrige);
}

/// Interroge une source. Null si elle n'a rien donné d'exploitable.
///
/// Ne lève jamais : une source muette est un fait ordinaire — coupure,
/// DNS lent, service en panne — pas un incident.
Future<MesureHeure?> interroger(SourceEnLigne s,
    {Duration delai = const Duration(seconds: 6)}) async {
  final client = HttpClient()..connectionTimeout = delai;
  try {
    final chrono = Stopwatch()..start();
    final debutLocal = DateTime.now();
    final req = await client.getUrl(s.uri);
    if (s.autorite) req.headers.set('apikey', CloudConfig.supabaseAnonKey);
    final rep = await req.close().timeout(delai);
    final corps = await rep.transform(utf8.decoder).join();
    chrono.stop();
    final t = s.lire(rep, corps);
    if (t == null) return null;
    return MesureHeure(
      source: s,
      heure: t,
      trajet: chrono.elapsed,
      // Le milieu du trajet, côté poste : le même repère que celui
      // qu'on applique à l'heure reçue.
      horlogePoste: debutLocal.add(chrono.elapsed ~/ 2),
    );
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
