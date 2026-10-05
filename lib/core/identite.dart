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

String _md5Uuid(String texte) =>
    _formater(md5.convert(utf8.encode(texte)).bytes);

String _formater(List<int> o) {
  final h = o.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
