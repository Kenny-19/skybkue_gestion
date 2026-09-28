import 'temps.dart';

/// L'heure de référence de l'application.
///
/// Pourquoi ne pas se contenter de `DateTime.now()`
/// ------------------------------------------------
/// Parce que l'horloge d'un poste ment, et qu'elle ment en silence. Le
/// 21 septembre 2026, celle de Lubumbashi avançait de deux heures : son
/// fuseau Windows était sur UTC pendant qu'elle affichait l'heure
/// locale. Le personnel voyait la bonne heure, l'application enregistrait
/// des instants faux, et 163 ventes sur 205 se sont retrouvées classées
/// au mauvais moment. Rien ne l'a signalé pendant des semaines : une
/// date fausse reste une date parfaitement valide.
///
/// Corriger les postes un par un ne suffit pas. Il suffit qu'une machine
/// reparte de travers — réinstallation, pile CMOS morte, un employé qui
/// « remet l'heure à l'endroit » — pour que les montants repartent de
/// travers avec elle, sans que personne ne le voie.
///
/// Comment elle marche
/// -------------------
/// Le serveur donne l'heure ; on ne la redemande pas à chaque fois. On
/// l'ANCRE une fois, puis on compte le temps écoulé depuis cet ancrage
/// avec un [Stopwatch].
///
/// Le chronomètre est MONOTONE, et c'est tout l'intérêt : il mesure une
/// durée, pas une date. Si quelqu'un change l'heure de Windows en plein
/// service, `DateTime.now()` fait un bond — le chronomètre, lui, continue
/// de compter comme si de rien n'était. L'heure rendue ici reste juste.
///
/// Ce que cette classe ne fait PAS
/// -------------------------------
/// Elle ne touche pas à l'horloge du système : ça demanderait des droits
/// administrateur et irait se battre avec Windows. Elle se contente de
/// savoir de combien il ment, et de rendre l'heure juste à qui la
/// demande.
class Horloge {
  Horloge._();

  /// Le chronomètre monotone depuis le dernier ancrage.
  static final _depuisAncrage = Stopwatch();

  /// L'heure du serveur au moment exact de l'ancrage.
  static DateTime? _ancre;

  /// Décalage retenu d'une session précédente, relu au démarrage.
  ///
  /// Sans lui, un poste qui démarre sans réseau repartirait sur son
  /// horloge fausse — c'est-à-dire précisément le matin où la connexion
  /// est coupée et où on a le plus besoin que ça tienne.
  static Duration? _decalageMemorise;

  /// Vrai quand l'heure vient du serveur, pas du poste.
  static bool get ancree => _ancre != null && _depuisAncrage.isRunning;

  /// Écart connu entre le poste et le serveur. Positif : le poste avance.
  static Duration? get decalage {
    if (ancree) return DateTime.now().difference(_instantAncre());
    return _decalageMemorise;
  }

  /// Fiabilité de l'heure rendue, pour qui veut la nuancer.
  static SourceHeure get source {
    if (ancree) return SourceHeure.serveur;
    if (_decalageMemorise != null) return SourceHeure.dernierAccord;
    return SourceHeure.posteSeul;
  }

  static DateTime _instantAncre() => _ancre!.add(_depuisAncrage.elapsed);

  /// L'heure qu'il est. **Le seul point d'entrée** pour tout horodatage
  /// destiné à être enregistré ou comparé.
  ///
  /// Rendue dans le fuseau du poste, mais l'INSTANT est le bon — et
  /// c'est l'instant qui est stocké et qui voyage. Pour afficher, passer
  /// par [aLubumbashi] : le fuseau du poste, lui, peut aussi être faux.
  static DateTime maintenant() {
    if (ancree) return _instantAncre().toLocal();
    final d = _decalageMemorise;
    return d == null ? DateTime.now() : DateTime.now().subtract(d);
  }

  /// Ancre l'heure sur celle du serveur.
  ///
  /// [heureServeur] est l'instant lu côté serveur, [allerRetour] la durée
  /// du trajet complet. On ajoute la moitié de ce trajet : l'heure a été
  /// écrite quelque part au milieu, et sans cette correction une liaison
  /// lente se lirait comme une horloge en retard.
  static void ancrer(DateTime heureServeur, Duration allerRetour) {
    _ancre = heureServeur.toUtc().add(allerRetour ~/ 2);
    _depuisAncrage
      ..reset()
      ..start();
    _decalageMemorise = DateTime.now().difference(_instantAncre());
  }

  /// Réinstalle un décalage retenu d'une session précédente.
  ///
  /// N'écrase jamais un ancrage en cours : une mesure fraîche vaut
  /// toujours mieux qu'un souvenir.
  static void restaurerDecalage(Duration d) {
    if (ancree) return;
    _decalageMemorise = d;
  }

  /// Remet tout à zéro. Réservé aux tests.
  static void oublier() {
    _ancre = null;
    _depuisAncrage
      ..stop()
      ..reset();
    _decalageMemorise = null;
  }

  /// La journée commerciale de Lubumbashi en cours.
  static ({DateTime debut, DateTime fin}) journee() =>
      journeeLubumbashi(maintenant());
}

/// D'où vient l'heure qu'on vient de rendre.
enum SourceHeure {
  /// Ancrée sur le serveur pendant cette session. C'est le cas normal.
  serveur,

  /// Pas de réseau, mais on se souvient du décalage mesuré la dernière
  /// fois. Bon tant que l'horloge du poste n'a pas été retouchée.
  dernierAccord,

  /// Le poste n'a jamais parlé au serveur. On rend son heure faute de
  /// mieux — et on le dit, pour que l'écran puisse le nuancer.
  posteSeul,
}
