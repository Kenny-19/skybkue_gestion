import 'mirror_service.dart';

/// Relecture du serveur PAR DIFFÉRENCE.
///
/// Avant : toutes les quinze secondes, chaque poste relisait en entier les
/// chambres, les clients, les payeurs, le catalogue et les 500 derniers
/// séjours — même quand rien n'avait bougé. Mesuré le 17 novembre 2026 :
/// 111 Ko par tour, environ 630 Mo par jour et par poste, et une charge
/// qui grandissait avec l'historique.
///
/// Désormais, à chaque tour :
///   1. une seule petite requête (`bs_versions`) dit quand chaque table a
///      changé pour la dernière fois ;
///   2. une table qui n'a pas bougé n'est pas relue ;
///   3. une table qui a bougé n'est relue que pour les lignes modifiées
///      depuis le passage précédent — sauf les chambres, peu nombreuses,
///      relues en entier parce qu'une suppression ne laisse pas de date.
///
/// Filets de sécurité :
///   * au démarrage, puis une fois par heure, tout est relu en entier ;
///   * le curseur recule de deux minutes : une modification enregistrée
///     pendant la lecture précédente n'est jamais perdue (relire deux fois
///     la même ligne ne coûte rien, les fonctions d'application n'écrivent
///     que ce qui change) ;
///   * serveur sans la fonction (script SQL pas encore passé) : on relit
///     tout, comme avant ;
///   * une table dont la lecture échoue garde son ancien curseur : elle
///     est retentée au tour suivant.
class SynchroParDifference {
  SynchroParDifference({
    Future<Map<String, dynamic>?> Function()? lireVersions,
    Future<void> Function()? toutRelire,
    Future<void> Function(String table, {DateTime? depuis})? tirer,
  })  : _lire = lireVersions ?? MirrorService.lireVersions,
        _toutRelire = toutRelire ?? MirrorService.toutRelire,
        _tirer = tirer ?? MirrorService.tirerChangements;

  static final SynchroParDifference instance = SynchroParDifference();

  final Future<Map<String, dynamic>?> Function() _lire;
  final Future<void> Function() _toutRelire;
  final Future<void> Function(String table, {DateTime? depuis}) _tirer;

  /// Payeurs avant les chambres : une chambre désigne son payeur.
  static const _ordre = [
    'payers',
    'clients',
    'articles',
    'rooms',
    'stays',
    'reservations',
  ];

  static const relectureComplete = Duration(hours: 1);
  static const recul = Duration(minutes: 2);

  /// Version de chaque table au dernier passage réussi.
  final Map<String, String> _vues = {};

  /// Date de dernière modification lue, d'où repartir.
  final Map<String, DateTime> _curseurs = {};
  DateTime? _derniereComplete;

  /// Un tour de relecture. Lève si le serveur ne répond pas : l'appelant
  /// le compte comme une coupure, rien n'est perdu.
  Future<void> tour({DateTime? maintenant}) async {
    final versions = await _lire();
    if (versions == null) {
      await _toutRelire();
      return;
    }
    final now = maintenant ?? DateTime.now();
    final complete = _derniereComplete == null ||
        now.difference(_derniereComplete!) >= relectureComplete;
    var toutReussi = true;

    for (final table in _ordre) {
      // Table que le serveur n'annonce pas : il ne la partage pas encore
      // (script SQL pas passé). On n'y touche pas.
      if (!versions.containsKey(table)) continue;
      final version = versionDe(versions, table);
      if (!complete && version != null && version == _vues[table]) continue;
      final curseur = complete ? null : _curseurs[table];
      try {
        await _tirer(table, depuis: curseur?.subtract(recul));
        if (version != null) _vues[table] = version;
        final max = maxDe(versions, table);
        if (max != null) _curseurs[table] = max;
      } catch (_) {
        toutReussi = false;
      }
    }
    if (complete && toutReussi) _derniereComplete = now;
  }

  /// Ce qui permet de savoir qu'une table a changé. Pour les chambres, le
  /// nombre de lignes aussi : une suppression ne change pas la date.
  static String? versionDe(Map<String, dynamic> versions, String table) {
    final v = versions[table];
    if (v == null) return null;
    if (v is Map) return '${v['max']}|${v['nb']}';
    return '$v';
  }

  /// Date de la dernière modification de [table].
  static DateTime? maxDe(Map<String, dynamic> versions, String table) {
    final v = versions[table];
    final brut = v is Map ? v['max'] : v;
    return brut is String ? DateTime.tryParse(brut) : null;
  }

  /// Pour les tests : repart de zéro.
  void oublier() {
    _vues.clear();
    _curseurs.clear();
    _derniereComplete = null;
  }
}
