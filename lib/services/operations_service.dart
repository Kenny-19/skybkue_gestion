import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../core/cloud_config.dart';
import '../core/horloge.dart';
import '../core/identite.dart';
import '../core/session_serveur.dart';
import '../data/database.dart';
import 'connexion_service.dart';
import 'error_reporter.dart';
import 'heartbeat_service.dart';
import 'mirror_service.dart';

/// Appel au serveur pour une opération : rend sa réponse
/// (`{status: ok}` ou `{status: refuse, motif, …}`).
typedef AppelOperation = Future<Map<String, dynamic>> Function(
    String type, Map<String, dynamic> payload, String opId, String session);

/// Le serveur a refusé l'opération : rien n'a été changé.
class OperationRefusee implements Exception {
  final String motif;
  final String? chambre;
  final String? occupant;
  const OperationRefusee(this.motif, {this.chambre, this.occupant});

  factory OperationRefusee.depuis(Map<String, dynamic> r) =>
      OperationRefusee((r['motif'] as String?) ?? 'REFUS',
          chambre: r['chambre'] as String?, occupant: r['occupant'] as String?);

  /// Le refus, dit simplement.
  String get message =>
      decrireRefus(motif, chambre: chambre, occupant: occupant);

  @override
  String toString() => message;
}

/// Un motif de refus du serveur, en clair.
String decrireRefus(String motif, {String? chambre, String? occupant}) {
  final ch = chambre == null ? 'La chambre' : 'La chambre $chambre';
  final qui = (occupant == null || occupant.isEmpty) ? '' : ' par $occupant';
  return switch (motif) {
    'CHAMBRE_OCCUPEE' =>
      '$ch est déjà occupée$qui (enregistré sur un autre poste).',
    'AUTRE_OCCUPANT' => '$ch est occupée$qui, pas par ce client : '
        'son départ a sans doute déjà été fait sur un autre poste.',
    'CHAMBRE_INCONNUE' => "$ch n'existe pas sur le serveur.",
    _ => 'Refusé par le serveur ($motif).',
  };
}

/// Comment une opération est passée.
enum Passage {
  /// Validée par le serveur, puis appliquée ici.
  enLigne,

  /// Appliquée ici, notée au journal, envoyée au retour du réseau.
  enAttente,

  /// Application sans serveur configuré : appliquée ici, rien à envoyer.
  local,

  /// Serveur pas encore à jour (script SQL pas passé) : appliquée ici, à
  /// envoyer par l'ancien chemin.
  ancienServeur,
}

/// Les opérations EN LIGNE D'ABORD, avec relais local pendant les coupures.
///
/// En ligne (le cas normal) : le serveur valide d'abord — c'est lui qui
/// sait si la chambre est libre, sur tous les postes — puis l'opération est
/// appliquée ici. S'il refuse, RIEN ne change ici, et la personne voit
/// pourquoi.
///
/// Hors ligne, ou sans session serveur sur ce poste : l'opération est
/// appliquée ici tout de suite (l'hôtel ne s'arrête pas), et notée au
/// journal. Au retour du réseau, [rejouer] l'envoie, dans l'ordre. Un refus
/// à ce moment-là est GARDÉ, avec son motif, dans la liste « À régler ».
class OperationsService {
  OperationsService(this._db,
      {AppelOperation? appel, ConnexionService? connexion})
      : _appelTest = appel,
        _cxTest = connexion;

  static OperationsService get instance =>
      _instance ??= OperationsService(AppDatabase.instance);
  static OperationsService? _instance;

  final AppDatabase _db;
  final AppelOperation? _appelTest;
  final ConnexionService? _cxTest;
  ConnexionService get _cx => _cxTest ?? ConnexionService.instance;

  AppelOperation? get _appel {
    if (_appelTest != null) return _appelTest;
    if (!CloudConfig.isConfigured) return null;
    return _appelServeur;
  }

  /// Exécute une opération. [appliquer] fait le changement ICI ; [chambres]
  /// sont protégées de la relecture du serveur tant que l'opération attend.
  ///
  /// LÈVE [OperationRefusee] si le serveur la refuse (rien n'a changé).
  Future<(T, Passage)> executer<T>({
    required String type,
    required Map<String, dynamic> payload,
    required String libelle,
    required Future<T> Function() appliquer,
    List<String> chambres = const [],
    String? auteur,
  }) async {
    final opId = nouvelUid();
    final appel = _appel;
    if (appel == null) return (await appliquer(), Passage.local);
    final jeton = SessionServeur.jeton;
    if (jeton != null && !_cx.estHorsLigne) {
      try {
        final r = await appel(type, payload, opId, jeton);
        if (r['status'] == 'refuse') throw OperationRefusee.depuis(r);
        unawaited(_cx.signalerEnLigne());
        return (await appliquer(), Passage.enLigne);
      } on OperationRefusee {
        rethrow;
      } catch (e) {
        if (_estFonctionAbsente(e)) {
          return (await appliquer(), Passage.ancienServeur);
        }
        if (_estSessionRefusee(e)) {
          await SessionServeur.oublier(_db);
        } else if (ConnexionService.estUneCoupure(e)) {
          _cx.signalerHorsLigne();
        } else {
          rethrow;
        }
        // Coupure ou session expirée : relais local, ci-dessous.
      }
    }

    // Relais local : appliqué ici, noté au journal.
    final resultat = await _db.transaction(() async {
      final v = await appliquer();
      await _db.into(_db.operations).insert(OperationsCompanion.insert(
            opId: opId,
            type: type,
            payload: jsonEncode(payload),
            libelle: libelle,
            auteur: Value(auteur ?? SessionServeur.login),
            creeLe: Horloge.maintenant(),
          ));
      if (chambres.isNotEmpty) {
        await (_db.update(_db.rooms)..where((r) => r.number.isIn(chambres)))
            .write(RoomsCompanion(pendingSince: Value(Horloge.maintenant())));
      }
      return v;
    });
    return (resultat, Passage.enAttente);
  }

  bool _occupe = false;

  /// Renvoie le journal au serveur, dans l'ordre. Une opération refusée
  /// est gardée avec son motif ; une coupure arrête le tour.
  Future<void> rejouer() async {
    if (_occupe) return;
    final appel = _appel;
    final jeton = SessionServeur.jeton;
    // Sans session, on attend la prochaine personne connectée en ligne.
    if (appel == null || jeton == null) return;
    _occupe = true;
    var refus = false;
    try {
      final attente = await (_db.select(_db.operations)
            ..where((o) => o.envoyeeLe.isNull() & o.refuseeLe.isNull())
            ..orderBy([(o) => OrderingTerm.asc(o.creeLe)]))
          .get();
      for (final o in attente) {
        try {
          final r = await appel(
              o.type,
              (jsonDecode(o.payload) as Map).cast<String, dynamic>(),
              o.opId,
              jeton);
          final maintenant = Horloge.maintenant();
          if (r['status'] == 'refuse') {
            refus = true;
            await (_db.update(_db.operations)
                  ..where((x) => x.opId.equals(o.opId)))
                .write(OperationsCompanion(
                    refuseeLe: Value(maintenant),
                    motif: Value(OperationRefusee.depuis(r).message)));
          } else {
            await (_db.update(_db.operations)
                  ..where((x) => x.opId.equals(o.opId)))
                .write(OperationsCompanion(
                    envoyeeLe: Value(maintenant),
                    lastError: const Value(null)));
          }
          await _liberer(o);
        } catch (e, st) {
          if (_estSessionRefusee(e)) {
            await SessionServeur.oublier(_db);
            break;
          }
          if (ConnexionService.estUneCoupure(e)) {
            _cx.signalerHorsLigne();
            break;
          }
          final essais = o.attempts + 1;
          await (_db.update(_db.operations)
                ..where((x) => x.opId.equals(o.opId)))
              .write(OperationsCompanion(
                  attempts: Value(essais), lastError: Value(e.toString())));
          if (essais == 5 || essais % 50 == 0) {
            unawaited(ErrorReporter.report(e, st,
                context: 'operations/${o.type} bloquée ($essais essais)'));
          }
          // Une opération bloquée arrête les suivantes : elles peuvent en
          // dépendre (une arrivée avant le départ du même client).
          break;
        }
      }
    } finally {
      _occupe = false;
    }
    // Refusée : le serveur n'a rien changé, sa date de modification non
    // plus — la relecture par différence ne verrait rien. On relit les
    // chambres tout de suite pour reprendre son état.
    if (refus && _appelTest == null) {
      unawaited(MirrorService.tirerChangements('rooms').catchError((_) {}));
    }
  }

  /// Plus d'opération en attente pour ces chambres : la relecture du
  /// serveur peut de nouveau les mettre à jour (et corriger un refus).
  Future<void> _liberer(Operation o) async {
    final numeros = chambresDe(o);
    if (numeros.isEmpty) return;
    final encore = await (_db.select(_db.operations)
          ..where((x) => x.envoyeeLe.isNull() & x.refuseeLe.isNull()))
        .get();
    final occupees = {for (final x in encore) ...chambresDe(x)};
    final libres = numeros.where((n) => !occupees.contains(n)).toList();
    if (libres.isEmpty) return;
    await (_db.update(_db.rooms)..where((r) => r.number.isIn(libres)))
        .write(const RoomsCompanion(pendingSince: Value(null)));
  }

  /// Les chambres concernées par une opération.
  static List<String> chambresDe(Operation o) {
    try {
      final p = jsonDecode(o.payload) as Map;
      return [
        for (final c in (p['chambres'] as List? ?? const []))
          (c as Map)['number'] as String
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Opérations pas encore acceptées par le serveur.
  Future<int> enAttente() async {
    final o = _db.operations;
    final q = _db.selectOnly(o)
      ..addColumns([o.opId.count()])
      ..where(o.envoyeeLe.isNull() & o.refuseeLe.isNull());
    return (await q.getSingle()).read(o.opId.count()) ?? 0;
  }

  /// Opérations refusées par le serveur, pas encore réglées.
  Stream<List<Operation>> watchARegler() => (_db.select(_db.operations)
        ..where((o) => o.refuseeLe.isNotNull() & o.regleeLe.isNull())
        ..orderBy([(o) => OrderingTerm.desc(o.refuseeLe)]))
      .watch();

  Future<void> marquerReglee(String opId) =>
      (_db.update(_db.operations)..where((o) => o.opId.equals(opId)))
          .write(OperationsCompanion(regleeLe: Value(Horloge.maintenant())));

  static bool _estSessionRefusee(Object e) =>
      e.toString().contains('SESSION_INVALIDE');

  /// Fonction serveur inconnue : script SQL pas encore passé.
  static bool _estFonctionAbsente(Object e) =>
      e is PostgrestException && (e.code == 'PGRST202' || e.code == '42883');

  static Future<Map<String, dynamic>> _appelServeur(String type,
      Map<String, dynamic> payload, String opId, String session) async {
    final c = Supabase.instance.client;
    final (fonction, params) = switch (type) {
      'chambres:arrivee' || 'chambres:depart' || 'chambres:statut' => (
          'bs_chambres_operer',
          {
            'p_session': session,
            'p_op_id': opId,
            'p_type': type.split(':').last,
            'p_chambres': payload['chambres'],
            'p_poste': HeartbeatService.nomDuPoste,
          }
        ),
      _ => throw StateError('Opération inconnue : $type'),
    };
    final r = await c
        .rpc(fonction, params: params)
        .timeout(const Duration(seconds: 8));
    return (r as Map).cast<String, dynamic>();
  }
}
