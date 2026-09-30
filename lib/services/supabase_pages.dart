import 'package:supabase_flutter/supabase_flutter.dart';

/// Taille d'une page. C'est le plafond `max_rows` du projet Supabase
/// (1000 par défaut, vérifié : une lecture de `mirror_sale_lines` a
/// renvoyé 1000 lignes sur 2792). Si on le baisse côté Supabase, il faut
/// le baisser ici aussi, sinon la boucle croirait avoir tout lu.
const int kTaillePageSupabase = 1000;

/// Lit TOUTES les lignes d'une requête, page par page.
///
/// Pourquoi ce passage obligé : au-delà de 1000 lignes, Supabase tronque
/// la réponse SANS erreur. Le 29 septembre 2026, la récupération des
/// ventes a reçu 1000 lignes d'articles sur 2792 et laissé 117 factures
/// vides. Pire, plusieurs lectures suppriment en local ce qui manque dans
/// la réponse (comptes, chambres) : une liste tronquée y devient une
/// suppression silencieuse.
///
/// [requete] doit construire la requête À NEUF à chaque appel (on la
/// rappelle pour chaque page) et la TRIER sur une colonne unique :
/// sans ordre stable, deux pages peuvent se chevaucher ou sauter des
/// lignes.
Future<List<Map<String, dynamic>>> toutesLesPages(
  PostgrestTransformBuilder<PostgrestList> Function() requete, {
  Duration? delaiParPage,
}) async {
  final tout = <Map<String, dynamic>>[];
  for (var debut = 0;; debut += kTaillePageSupabase) {
    Future<PostgrestList> page =
        requete().range(debut, debut + kTaillePageSupabase - 1);
    if (delaiParPage != null) page = page.timeout(delaiParPage);
    final lot = await page;
    tout.addAll(lot);
    if (lot.length < kTaillePageSupabase) return tout;
  }
}

/// Même chose pour un filtre `in` sur une longue liste d'ids : découpe en
/// paquets (une URL trop longue est refusée), et pagine chaque paquet.
Future<List<Map<String, dynamic>>> toutesLesPagesParIds(
  List<Object> ids,
  PostgrestTransformBuilder<PostgrestList> Function(List<Object> paquet)
      requete, {
  int taillePaquet = 100,
}) async {
  final tout = <Map<String, dynamic>>[];
  for (var i = 0; i < ids.length; i += taillePaquet) {
    final paquet = ids.sublist(i, (i + taillePaquet).clamp(0, ids.length));
    tout.addAll(await toutesLesPages(() => requete(paquet)));
  }
  return tout;
}
