// Normalisation du type de chambre.
//
// Le problème constaté en production : la même chose s'écrivait de
// quatre façons — `standard` (14 chambres), `Standard`, `STANDARD` — et
// la chambre 19 portait `230000` comme type, parce que quelqu'un avait
// tapé le prix dans le mauvais champ.
//
// Nettoyer la base sans normaliser À LA SAISIE ne ferait que repousser
// le problème de quelques semaines. Cette fonction sert donc aux deux :
// la migration v20 et chaque création ou modification de chambre.

/// Type de chambre affichable, ou null si la valeur n'en est pas un.
///
/// Retourne null pour un champ vide ET pour une valeur purement
/// numérique — un prix saisi par erreur n'est pas un type, et inventer
/// « 230000 » comme catégorie de chambre serait pire que de le signaler.
/// L'appelant décide du repli : la migration retrouve le type par le
/// prix, la saisie retombe sur « Standard ».
///
/// Casse française : une majuscule au premier mot seulement — « Suite
/// junior », pas « Suite Junior ». Les sigles courts en majuscules
/// (VIP, T2) sont préservés, parce que « Vip » serait une faute.
String? normalizeRoomType(String raw) {
  final clean = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (clean.isEmpty) return null;
  if (looksLikePrice(clean)) return null;

  final mots = clean.split(' ');
  final out = <String>[];
  for (var i = 0; i < mots.length; i++) {
    final m = mots[i];
    if (_estSigle(m)) {
      out.add(m);
    } else if (i == 0) {
      out.add(m[0].toUpperCase() + m.substring(1).toLowerCase());
    } else {
      out.add(m.toLowerCase());
    }
  }
  return out.join(' ');
}

/// Vrai quand la valeur est un nombre déguisé en type — typiquement un
/// prix saisi dans le mauvais champ. Les séparateurs de milliers et le
/// suffixe FC sont tolérés : « 230 000 FC » est tout aussi bien un prix.
bool looksLikePrice(String raw) {
  final s = raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s.,]'), '')
      .replaceAll('fc', '')
      .replaceAll(r'$', '');
  if (s.isEmpty) return false;
  return RegExp(r'^\d+$').hasMatch(s);
}

/// Un sigle qu'on laisse en majuscules : court, et entièrement en
/// capitales dans la saisie d'origine.
bool _estSigle(String mot) =>
    mot.length <= 3 &&
    mot == mot.toUpperCase() &&
    RegExp(r'^[A-Z0-9]+$').hasMatch(mot);

/// Ce qu'on écrit quand aucun type utilisable n'a pu être déterminé.
const String kTypeChambreParDefaut = 'Standard';
