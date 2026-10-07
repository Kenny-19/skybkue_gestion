import 'dart:async';

import 'error_reporter.dart';
import 'mirror_service.dart';
import 'ventes_outbox.dart';

/// Poll Supabase toutes les [interval] secondes pour rapatrier les
/// chambres et les comptes utilisateurs modifiés par un autre poste.
///
/// Modèle : chaque poste écrit d'abord en local, puis pousse vers
/// `mirror_rooms` / `mirror_users` (best-effort, cf. [MirrorService]).
/// Ce service tire à intervalle régulier ce que les autres postes ont
/// écrit, et fusionne dans la BDD locale. Comme la BDD locale est
/// observée par des streams Drift, l'UI se met à jour automatiquement.
class MirrorPullService {
  MirrorPullService._();
  static final MirrorPullService instance = MirrorPullService._();

  Timer? _timer;
  bool _busy = false;
  DateTime? _lastPull;

  /// Dernière remontée complète réussie vers le miroir.
  DateTime? _dernierePoussee;

  /// Le passage précédent a-t-il échoué ? Sert à détecter le RETOUR du
  /// réseau : c'est l'instant où il faut tout remonter.
  bool _etaitHorsLigne = false;

  /// Filet de sécurité : même sans coupure détectée, on repousse tout
  /// de temps en temps. Un échec silencieux sur une vente isolée ne doit
  /// pas la laisser absente du tableau de bord pour la journée.
  static const Duration _intervallePoussee = Duration(minutes: 10);

  /// 15 s : compromis entre fraîcheur (voir un check-in de l'autre poste
  /// vite) et charge Supabase (quotas free tier). Peut être ajusté à la
  /// volée depuis les Paramètres si besoin.
  Duration interval = const Duration(seconds: 15);

  DateTime? get lastPull => _lastPull;

  /// Synchronisations complètes ratées d'affilée, et le moment avant
  /// lequel on n'en retente pas d'autre.
  int _echecsSync = 0;
  DateTime? _prochainEssai;

  /// Attente avant de retenter une synchronisation complète ratée
  /// [echecs] fois d'affilée : 15 s, 30 s, 1 min, 2 min… plafonnée à
  /// 10 min, l'intervalle normal.
  static Duration delaiAvantNouvelEssai(int echecs) {
    if (echecs <= 0) return Duration.zero;
    final secondes = 15 * (1 << (echecs - 1).clamp(0, 10));
    return Duration(seconds: secondes.clamp(15, 600));
  }

  void start() {
    if (_timer != null) return;
    // Pull immédiat au démarrage puis à intervalle régulier.
    unawaited(_tick());
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Dernière erreur de synchronisation, null si le dernier passage
  /// s'est bien terminé. Affichée dans les Réglages.
  String? get lastError => _lastError;
  String? _lastError;

  /// Force un pull immédiat (bouton "Actualiser").
  Future<void> pullNow() => _tick();

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      // Les comptes ne sont plus tirés ici : ils vivent dans app_users
      // et se rafraîchissent via UsersRepo.syncFromCloud(), qui remonte
      // ses erreurs à l'écran Comptes au lieu de les avaler.
      await Future.wait([
        MirrorService.pullRoomsIntoLocal(),
        MirrorService.pullClientsIntoLocal(),
        MirrorService.pullPayersIntoLocal(),
        // Catalogue et fiches produits : sans ça, le seul moyen de
        // récupérer un article créé sur un autre poste était le bouton
        // « Récupérer depuis les données miroir », qui rase la base.
        MirrorService.pullArticlesIntoLocal(),
        // Historique de l'hôtel. Les séjours partaient vers le serveur
        // sans que personne ne les relise : chaque poste ne voyait que
        // ses propres check-out, et rien ne signalait le manque.
        MirrorService.pullStaysIntoLocal(),
      ]);

      // La file des ventes est vidée à CHAQUE tour, pas seulement
      // toutes les dix minutes comme la synchro complète. Une vente
      // encaissée pendant une micro-coupure part donc dans les quinze
      // secondes qui suivent le retour du réseau, au lieu d'attendre.
      unawaited(VentesOutbox.instance.vider());
      _lastPull = DateTime.now();
      _lastError = null;

      // Le réseau vient de revenir, ou la dernière remontée date : on
      // pousse TOUT vers le miroir. `syncAll` est un upsert par id, donc
      // rejouer est sans effet sur ce qui est déjà là.
      //
      // C'est ce qui manquait : `syncAll` ne tournait qu'au démarrage.
      // Une coupure au lancement laissait la journée entière invisible
      // pour le gérant, même une fois la connexion revenue.
      final poussee = _dernierePoussee;
      final maintenant = DateTime.now();
      final essaiPermis =
          _prochainEssai == null || !maintenant.isBefore(_prochainEssai!);
      final aRattraper = (_etaitHorsLigne && essaiPermis) ||
          poussee == null ||
          maintenant.difference(poussee) > _intervallePoussee;
      if (aRattraper) {
        _etaitHorsLigne = false;
        await MirrorService.syncAll();
        _dernierePoussee = DateTime.now();
        // `syncAll` ne lève plus : c'est son bilan qui dit si tout est
        // passé. En cas d'échec, on retente — mais de plus en plus loin.
        //
        // Le 7 octobre 2026, une erreur PERMANENTE (envoi des comptes
        // refusé par le serveur) relançait la synchronisation complète à
        // chaque tour de quinze secondes : une quarantaine d'échecs toutes
        // les dix minutes, et tout le catalogue renvoyé quatre fois par
        // minute. Une coupure passagère, elle, est toujours rattrapée vite.
        final bilan = MirrorService.dernierBilan;
        if (bilan != null && bilan.cloudConfigured && !bilan.ok) {
          _echecsSync++;
          _etaitHorsLigne = true;
          _prochainEssai =
              DateTime.now().add(delaiAvantNouvelEssai(_echecsSync));
          _lastError = bilan.errors.join(' · ');
        } else {
          _echecsSync = 0;
          _prochainEssai = null;
        }
      }
    } catch (e, st) {
      // Best-effort, mais plus silencieux : on garde la dernière erreur
      // pour l'afficher et on la remonte au reporting.
      _lastError = e.toString();
      // Au prochain passage réussi, on saura qu'il faut tout remonter.
      _etaitHorsLigne = true;
      unawaited(ErrorReporter.report(e, st, context: 'mirrorPull'));
    } finally {
      _busy = false;
    }
  }
}
