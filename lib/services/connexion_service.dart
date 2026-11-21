import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../core/cloud_config.dart';
import '../core/temps.dart';
import '../data/database.dart';
import '../data/repos.dart';
import 'heartbeat_service.dart';

/// Le poste joint-il le serveur ?
enum EtatConnexion {
  /// Pas encore su (démarrage), ou application sans serveur configuré.
  inconnu,
  enLigne,
  horsLigne,
}

/// Une coupure : du premier échec au premier succès suivant.
class Coupure {
  final DateTime debut;
  final DateTime fin;
  const Coupure(this.debut, this.fin);
  Duration get duree => fin.difference(debut);

  Map<String, dynamic> toJson() =>
      {'debut': isoServeur(debut), 'fin': isoServeur(fin)};
  static Coupure fromJson(Map<String, dynamic> j) => Coupure(
      DateTime.parse(j['debut'] as String).toLocal(),
      DateTime.parse(j['fin'] as String).toLocal());
}

/// État de la connexion au serveur, et journal des coupures.
///
/// L'application travaille EN LIGNE D'ABORD : tant que le serveur répond,
/// c'est lui qui fait foi. Quand il ne répond plus, elle bascule sur la
/// copie locale et met les opérations en file ; au retour du réseau, elle
/// les renvoie. Ce service dit dans quel cas on est — pour l'afficher, et
/// pour que chaque opération sache par où passer.
///
/// Il mesure aussi les coupures, et les envoie au serveur au retour. On ne
/// savait pas combien de temps les postes passaient sans réseau : l'ancien
/// code abandonnait ce qui était fait pendant une coupure, et ce qui
/// n'arrivait jamais ne laissait aucune trace.
class ConnexionService {
  ConnexionService({AppDatabase? db, this.envoyer}) : _dbTest = db;

  static final ConnexionService instance = ConnexionService();

  final AppDatabase? _dbTest;
  AppDatabase get _db => _dbTest ?? AppDatabase.instance;

  /// Pour les tests : remplace l'envoi des coupures au serveur.
  final Future<void> Function(List<Coupure>)? envoyer;

  final ValueNotifier<EtatConnexion> etat =
      ValueNotifier(EtatConnexion.inconnu);

  /// Début de la coupure en cours, null en ligne.
  DateTime? horsLigneDepuis;

  static const _cle = 'coupures_a_envoyer';

  bool get estHorsLigne => etat.value == EtatConnexion.horsLigne;

  /// [e] est-elle une coupure réseau (et non un refus du serveur, qui lui
  /// a bien répondu) ?
  static bool estUneCoupure(Object e) {
    if (e is TimeoutException) return true;
    final t = e.toString().toLowerCase();
    return t.contains('socket') ||
        t.contains('timeout') ||
        t.contains('timed out') ||
        t.contains('failed host lookup') ||
        t.contains('connection') ||
        t.contains('network');
  }

  /// Le serveur vient de répondre.
  Future<void> signalerEnLigne({DateTime? maintenant}) async {
    final now = maintenant ?? DateTime.now();
    final debut = horsLigneDepuis;
    horsLigneDepuis = null;
    etat.value = EtatConnexion.enLigne;
    if (debut != null) {
      await _memoriser(Coupure(debut, now));
    }
    unawaited(envoyerCoupures());
  }

  /// Le serveur n'a pas répondu (réseau coupé, délai dépassé).
  void signalerHorsLigne({DateTime? maintenant}) {
    if (etat.value == EtatConnexion.horsLigne) return;
    horsLigneDepuis = maintenant ?? DateTime.now();
    etat.value = EtatConnexion.horsLigne;
  }

  /// Coupures mesurées, pas encore envoyées au serveur. Gardées en base :
  /// une coupure qui finit par un redémarrage n'est pas perdue.
  Future<List<Coupure>> enAttente() async {
    final brut = await SettingsRepo(_db).lireBrut(_cle);
    if (brut == null || brut.isEmpty) return [];
    try {
      return [
        for (final j in jsonDecode(brut) as List)
          Coupure.fromJson((j as Map).cast<String, dynamic>())
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _memoriser(Coupure c) async {
    final liste = [...await enAttente(), c];
    // Plafond : un poste resté des semaines sans envoyer ne doit pas
    // faire grossir ce réglage sans fin.
    final garde =
        liste.length > 500 ? liste.sublist(liste.length - 500) : liste;
    await SettingsRepo(_db)
        .ecrireBrut(_cle, jsonEncode([for (final x in garde) x.toJson()]));
  }

  bool _envoi = false;

  /// Envoie les coupures mesurées. Silencieux en cas d'échec : elles
  /// repartiront au retour suivant.
  Future<void> envoyerCoupures() async {
    if (_envoi) return;
    _envoi = true;
    try {
      final liste = await enAttente();
      if (liste.isEmpty) return;
      final f = envoyer ?? _envoyerAuServeur;
      await f(liste);
      // Seulement celles envoyées : une coupure notée pendant l'envoi reste.
      final reste = (await enAttente()).skip(liste.length).toList();
      await SettingsRepo(_db)
          .ecrireBrut(_cle, jsonEncode([for (final x in reste) x.toJson()]));
    } catch (_) {
      // Prochain retour en ligne.
    } finally {
      _envoi = false;
    }
  }

  static Future<void> _envoyerAuServeur(List<Coupure> liste) async {
    if (!CloudConfig.isConfigured) return;
    final poste = HeartbeatService.nomDuPoste;
    await Supabase.instance.client.from('app_coupures').insert([
      for (final c in liste)
        {
          'poste': poste,
          'debut': isoServeur(c.debut),
          'fin': isoServeur(c.fin),
        }
    ]);
  }
}
