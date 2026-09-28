import 'dart:async';

import 'package:drift/drift.dart';

import '../core/horloge.dart';
import '../data/database.dart';
import 'sources_heure.dart';

/// Surveillance de l'horloge du poste.
///
/// Pourquoi ce service existe
/// --------------------------
/// Le 21 septembre 2026, un relevé a montré que le poste principal
/// avançait de deux heures sur l'UTC réel : son fuseau Windows était
/// réglé sur UTC alors que son horloge affichait l'heure de Lubumbashi.
/// Le personnel voyait la bonne heure — c'est l'instant absolu qui était
/// faux, et lui seul voyage jusqu'au serveur.
///
/// Conséquence : 163 ventes sur 205 étaient enregistrées deux heures
/// dans le futur. Toute vente après 22h basculait sur le lendemain, et
/// le chiffre du jour de Pamela perdait sa fin de soirée.
///
/// Aucun code ne peut deviner ça tout seul : une date fausse est une
/// date valide. Le seul recours est de DEMANDER l'heure à quelqu'un qui
/// la connaît — ici le serveur, dont chaque réponse HTTP porte l'en-tête
/// `Date`. Ça ne coûte pas de SQL, pas de RPC, pas de dépendance.
class HorlogeService {
  HorlogeService._();
  static final instance = HorlogeService._();

  /// Au-delà, on considère que l'horloge est fausse.
  ///
  /// Cinq minutes : assez large pour qu'un poste sans synchronisation
  /// réseau ne crie pas pour quelques secondes de dérive, assez étroit
  /// pour attraper une erreur de fuseau, qui se compte en heures.
  static const seuil = Duration(minutes: 5);

  /// Dernière dérive mesurée. Positive : le poste AVANCE sur le serveur.
  Duration? get derive => _derive;
  Duration? _derive;

  DateTime? get mesureeLe => _mesureeLe;
  DateTime? _mesureeLe;

  bool get horlogeSuspecte {
    final d = _derive;
    return d != null && d.abs() > seuil;
  }

  /// Ce qu'il faut dire à un gérant, ou null si tout va bien.
  String? get avertissement {
    final d = _derive;
    if (d == null || d.abs() <= seuil) return null;
    final h = d.inMinutes.abs() ~/ 60;
    final m = d.inMinutes.abs() % 60;
    final ecart = h > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '$m min';
    final sens = d.isNegative ? 'retarde' : 'avance';
    // Le ton compte ici. Depuis que l'application prend son heure sur le
    // serveur, ce décalage n'abîme plus les enregistrements — annoncer
    // une catastrophe ferait paniquer pour rien, et à force on
    // n'écouterait plus les vraies alertes.
    return "L'horloge de Windows $sens de $ecart sur le serveur. "
        "Les ventes restent datées correctement : l'application prend "
        "son heure en ligne. Mais si ce poste démarre un jour sans "
        'connexion, il repartira sur cette heure-là. Corrige la date, '
        "l'heure et le fuseau de Windows (UTC+02:00 pour Lubumbashi) "
        'quand tu peux.';
  }

  /// Nom de la source sur laquelle l'heure a été ancrée.
  String? get sourceUtilisee => _sourceUtilisee;
  String? _sourceUtilisee;

  /// Désaccord constaté entre le serveur et une source indépendante.
  ///
  /// Null quand tout le monde s'accorde. Non null, c'est le signe qu'une
  /// des deux horloges dérive — probablement pas celle de Google.
  Duration? get desaccord => _desaccord;
  Duration? _desaccord;

  /// Interroge les sources en ligne et ancre [Horloge] sur la bonne.
  ///
  /// Renvoie null si AUCUNE source n'a répondu — hors ligne. Ce n'est
  /// pas une alerte : on ne transforme pas une coupure réseau en panne
  /// d'horloge.
  ///
  /// La stratégie, et pourquoi elle est dans cet ordre
  /// -------------------------------------------------
  ///  1. Supabase d'abord, plusieurs fois, et on garde l'aller-retour le
  ///     plus court. C'est LUI qui fait foi : son horloge pose les
  ///     `synced_at` et date tout côté serveur. Une source externe plus
  ///     juste dans l'absolu mais désaccordée avec lui réintroduirait le
  ///     décalage qu'on vient d'éliminer.
  ///  2. Les autres sources servent de TÉMOIN. Si elles contredisent
  ///     Supabase de plus de [toleranceDesaccord], on garde quand même
  ///     Supabase — mais on le dit.
  ///  3. Si Supabase ne répond pas du tout, on se rabat sur elles :
  ///     mieux vaut une heure mondiale qu'une horloge de poste dont on
  ///     sait qu'elle ment.
  Future<Duration?> mesurer({int essais = 3}) async {
    final sources = sourcesHeure();
    final autorite = sources.where((s) => s.autorite);

    MesureHeure? meilleure;
    for (final s in autorite) {
      meilleure = await _plusieursFois(s, essais);
    }

    // Témoins : une source indépendante, la plus rapide qui réponde.
    MesureHeure? temoin;
    for (final s in sources.where((s) => !s.autorite)) {
      temoin = await interroger(s);
      if (temoin != null) break;
    }

    if (meilleure != null && temoin != null) {
      // On compare les DÉCALAGES par rapport au poste, pas les instants.
      // Les deux sources ont été interrogées l'une après l'autre : leurs
      // instants diffèrent forcément du temps écoulé entre les deux, et
      // comparer ça ferait passer quelques secondes de réseau pour un
      // désaccord d'horloge.
      final ecart =
          (meilleure.decalagePoste - temoin.decalagePoste).abs();
      _desaccord = ecart > toleranceDesaccord ? ecart : null;
    } else {
      _desaccord = null;
    }

    // Supabase muet : on prend le témoin plutôt que l'horloge du poste.
    final retenue = meilleure ?? temoin;
    if (retenue == null) return null;

    Horloge.ancrer(retenue.heure, retenue.trajet);
    _sourceUtilisee = retenue.source.nom;
    _derive = Horloge.decalage;
    _mesureeLe = DateTime.now();
    unawaited(_memoriser());
    return _derive;
  }

  /// Au-delà, deux sources ne racontent plus la même histoire.
  ///
  /// Trente secondes : bien au-dessus du bruit d'un aller-retour, très
  /// en dessous d'une erreur de fuseau. Le sondage du 21 septembre a
  /// trouvé une API publique qui se trompait de quatre heures — c'est ce
  /// genre d'écart qu'on veut voir, pas une demi-seconde de latence.
  static const toleranceDesaccord = Duration(seconds: 30);

  /// Interroge une source plusieurs fois, garde le trajet le plus court.
  ///
  /// La correction appliquée est la moitié de l'aller-retour : plus il
  /// est court, moins on extrapole. Une requête qui traîne deux secondes
  /// sur une liaison congestionnée donne une mesure grossière, et c'est
  /// précisément ce qu'on ne veut pas ancrer.
  Future<MesureHeure?> _plusieursFois(SourceEnLigne s, int essais) async {
    MesureHeure? meilleure;
    for (var i = 0; i < essais; i++) {
      final m = await interroger(s);
      if (m == null) continue;
      if (meilleure == null || m.trajet < meilleure.trajet) meilleure = m;
      // Sous 200 ms, on ne fera guère mieux : inutile de faire patienter
      // le démarrage.
      if (meilleure.trajet < const Duration(milliseconds: 200)) break;
    }
    return meilleure;
  }

  /// Garde le décalage d'une session à l'autre.
  ///
  /// Un poste qui démarre sans réseau repartirait sinon sur son horloge
  /// fausse — c'est-à-dire le matin où la connexion est coupée, celui où
  /// on a le plus besoin que ça tienne.
  Future<void> _memoriser() async {
    final d = _derive;
    if (d == null) return;
    try {
      await AppDatabase.instance.into(AppDatabase.instance.settings).insert(
            SettingsCompanion.insert(
                key: _cleReglage, value: d.inMilliseconds.toString()),
            mode: InsertMode.insertOrReplace,
          );
    } catch (_) {
      // Un décalage non mémorisé se remesurera au prochain démarrage.
    }
  }

  /// Relit le décalage de la dernière session. À appeler AVANT la
  /// première mesure, au démarrage.
  Future<void> relireDecalageMemorise() async {
    try {
      final db = AppDatabase.instance;
      final r = await (db.select(db.settings)
            ..where((s) => s.key.equals(_cleReglage)))
          .getSingleOrNull();
      final ms = int.tryParse(r?.value ?? '');
      if (ms != null) {
        Horloge.restaurerDecalage(Duration(milliseconds: ms));
        _derive = Horloge.decalage;
      }
    } catch (_) {
      // Base pas encore prête : on s'en passera.
    }
  }

  static const _cleReglage = 'horloge_decalage_ms';

  /// L'heure qu'il est vraiment, corrigée de la dérive connue.
  ///
  /// Utile pour les bornes de journée quand on sait l'horloge fausse.
  /// Sans mesure, on rend l'heure du poste : faute de mieux.
  DateTime maintenant() => Horloge.maintenant();

  /// La journée commerciale de Lubumbashi, vue à l'heure corrigée.
  ({DateTime debut, DateTime fin}) journeeCourante() => Horloge.journee();
}
