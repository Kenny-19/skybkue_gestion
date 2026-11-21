import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Identité des ventes, valable sur TOUS les postes.
///
/// Le problème qu'elle règle
/// -------------------------
/// `sales.id` est un compteur propre à chaque poste. Le miroir Supabase
/// l'utilisait tel quel comme clé : la vente n° 345 de la caisse et la
/// vente n° 345 de la réception étaient la même ligne pour le serveur, et
/// la dernière envoyée écrasait l'autre.
///
/// Désormais chaque vente et chaque ligne portent un `uid`, créé par le
/// poste au moment de l'encaissement. C'est lui que le serveur reconnaît.
/// Le numéro local reste celui du ticket.

final Random _hasard = Random.secure();

/// Identifiant neuf, au format UUID v4.
String nouvelUid() {
  final o = List<int>.generate(16, (_) => _hasard.nextInt(256));
  o[6] = (o[6] & 0x0f) | 0x40; // version 4
  o[8] = (o[8] & 0x3f) | 0x80; // variante RFC 4122
  return _formater(o);
}

/// Identifiant d'une vente ANTÉRIEURE à l'identité : déduit de son numéro
/// local et de son heure de vente, à la seconde.
///
/// Deux postes ont pu produire la même vente n° 345, mais pas à la même
/// seconde : les deux obtiennent des identifiants différents.
///
/// ⚠️ La même formule tourne côté serveur sur les lignes déjà présentes
/// (sql/2026_10_identite_ventes.sql) :
///   md5(id::text || '|' || floor(extract(epoch from sold_at))::bigint::text)::uuid
/// Les deux doivent rester identiques au caractère près, sinon une vente
/// ne retrouverait pas sa propre ligne sur le serveur.
String uidVenteHerite(int id, DateTime soldAt) =>
    _md5Uuid('$id|${soldAt.millisecondsSinceEpoch ~/ 1000}');

/// Identifiant d'une ligne antérieure : dérivé de l'identifiant de sa
/// vente et de son numéro local. Même formule côté serveur :
///   md5(sale_uid || '|' || id::text)::uuid
String uidLigneHerite(String uidVente, int idLigne) =>
    _md5Uuid('$uidVente|$idLigne');

/// Identifiant d'un séjour ANTÉRIEUR à l'identité : déduit de son numéro
/// local et de son heure de départ. Le préfixe « S| » le distingue d'une
/// vente de même numéro à la même seconde. Même formule côté serveur
/// (sql/2026_10_identite_sejours.sql) :
///   md5('S|' || id::text || '|' || floor(extract(epoch from checkout_at))::bigint::text)::uuid
String uidSejourHerite(int id, DateTime checkoutAt) =>
    _md5Uuid('S|$id|${checkoutAt.millisecondsSinceEpoch ~/ 1000}');

/// Identifiant d'un ARTICLE : déduit de son nom, sur tous les postes.
///
/// Les postes reconnaissaient déjà un produit à son nom ; deux postes qui
/// créent « Fanta » parlent du même produit. Calculé une fois, à la
/// création (ou à l'arrivée de la v28), puis gardé : renommer un article
/// ne change pas son identité.
///
/// Même formule côté serveur (sql/2026_10_identite_articles.sql) :
///   md5('A|' || btrim(name))::uuid
/// `btrim` ne retire que les espaces : on fait de même ici.
String uidArticle(String nom) =>
    _md5Uuid('A|${nom.replaceAll(RegExp(r'^ +| +$'), '')}');

/// Identifiant d'un CLIENT : déduit de son téléphone, ou de son nom
/// s'il n'en a pas — ce qui le faisait déjà reconnaître d'un poste à
/// l'autre. Calculé à la création, puis gardé.
///
/// Même formule côté serveur (sql/2026_10_identite_clients_payeurs.sql) :
///   téléphone : md5('C|T|' || btrim(phone))::uuid
///   sinon     : md5('C|N|' || bs_minuscules(btrim(full_name)))::uuid
String uidClient(String nom, String? telephone) {
  final tel = telephone == null ? '' : _btrim(telephone);
  return tel.isNotEmpty
      ? _md5Uuid('C|T|$tel')
      : _md5Uuid('C|N|${_minuscules(_btrim(nom))}');
}

/// Identifiant d'un PAYEUR (société, prise en charge) : déduit de son nom.
///   md5('P|' || bs_minuscules(btrim(name)))::uuid
String uidPayeur(String nom) => _md5Uuid('P|${_minuscules(_btrim(nom))}');

/// Identifiant d'une RÉSERVATION antérieure à l'identité : déduite de son
/// numéro local et de son heure de création, comme les ventes.
String uidReservationHeritee(int id, DateTime creeeLe) =>
    _md5Uuid('R|$id|${creeeLe.millisecondsSinceEpoch ~/ 1000}');

/// `btrim` de PostgreSQL : seulement les espaces, aux deux bouts.
String _btrim(String s) => s.replaceAll(RegExp(r'^ +| +$'), '');

const _majuscules = 'ABCDEFGHIJKLMNOPQRSTUVWXYZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ';
const _minuscules_ = 'abcdefghijklmnopqrstuvwxyzàáâãäåçèéêëìíîïñòóôõöùúûüý';

/// Mise en minuscules par une table EXPLICITE, et non `toLowerCase()` :
/// le serveur applique exactement la même (`bs_minuscules`), alors que
/// les deux fonctions natives ne s'accordent pas sur tous les caractères.
String _minuscules(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = _majuscules.indexOf(c);
    b.write(i < 0 ? c : _minuscules_[i]);
  }
  return b.toString();
}

String _md5Uuid(String texte) =>
    _formater(md5.convert(utf8.encode(texte)).bytes);

String _formater(List<int> o) {
  final h = o.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
