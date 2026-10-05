import 'package:drift/drift.dart';

import '../core/identite.dart';

// Enums stockés en index int (sqlite n'a pas de vrai enum).
// L'ordre doit rester stable — ne jamais réordonner.

// `gerant` occupe toujours l'index 1 : renommer une valeur est sans
// effet sur les bases existantes, la reordonner les casserait.
enum DbUserRole { superAdmin, gerant, serveur, reception }

enum DbCategory { boissons, nourriture, chambres }

enum DbRoomStatus { libre, occupee, nettoyage, maintenance }

enum DbPayment { cash, card, mobileMoney }

enum DbLocation { restaurant, terrasse, hotel }

enum DbPayerType { individual, company }

enum DbReservationStatus { pending, confirmed, checkedIn, cancelled, noShow }

/// Vie d'un séjour. Ajouté à la fin seulement : la position est stockée.
///   * enCours        : client arrivé, pas encore parti ;
///   * facture        : parti, facture émise (tous les séjours d'avant
///                      la v27 sont dans cet état) ;
///   * sansFacture    : chambre libérée sans facture — il en reste une
///                      trace, il n'en restait aucune ;
///   * clotureAilleurs : le départ a été fait sur un autre poste.
enum DbStayStatus { enCours, facture, sansFacture, clotureAilleurs }

/// Réglages application (clé/valeur). Ex: taux de change USD→FC.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fullName => text().withLength(min: 1, max: 120)();
  TextColumn get login => text().withLength(min: 2, max: 40).unique()();
  TextColumn get passwordHash => text()();
  IntColumn get role => intEnum<DbUserRole>()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastLogin => dateTime().nullable()();

  /// Compte de secours créé à l'installation (réception / serveuse /
  /// admin). Ces comptes vivent UNIQUEMENT en local : jamais poussés
  /// vers Supabase, jamais supprimés par une synchro. Tous les autres
  /// comptes ont Supabase pour source de vérité.
  BoolColumn get isLocalDefault =>
      boolean().withDefault(const Constant(false))();

  /// Le compte porte encore le mot de passe provisoire (0000) posé à sa
  /// création : la connexion exige un changement avant d'ouvrir l'app.
  ///
  /// Sans ce drapeau, un défaut universel connu de tous serait une porte
  /// ouverte. C'est lui qui rend le provisoire acceptable.
  BoolColumn get mustChangePassword =>
      boolean().withDefault(const Constant(false))();

  /// Dernière synchronisation réussie depuis Supabase. Null → compte
  /// jamais synchronisé (compte de secours, ou créé hors ligne).
  DateTimeColumn get syncedAt => dateTime().nullable()();
}

/// Produit unique : sert à la fois de ligne du menu (catalogue) et
/// d'article de stock. La gestion (prix, photo, quantité) se fait dans
/// l'écran Stock ; le Catalogue n'en est que l'affichage (menu).
class Articles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  IntColumn get priceCents => integer()();
  IntColumn get category => intEnum<DbCategory>()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  // Chemin/URL d'une image (photo produit). Vide → icône générique.
  TextColumn get imagePath => text().nullable()();
  // Gestion de stock intégrée.
  // trackStock=false → produit vendu sans décompte (ex. chambres).
  BoolColumn get trackStock => boolean().withDefault(const Constant(false))();
  TextColumn get unit => text().withDefault(const Constant('unité'))();
  IntColumn get stockQty => integer().withDefault(const Constant(0))();
  IntColumn get threshold => integer().withDefault(const Constant(0))();

  /// Identité de l'article sur tous les postes (v28), déduite du nom à la
  /// création (cf. core/identite.dart, uidArticle). Le serveur et les
  /// mouvements de stock le reconnaissent par là, plus par son numéro
  /// local — qui désignait parfois un autre produit sur le serveur.
  TextColumn get uid => text().nullable()();
}

class Rooms extends Table {
  TextColumn get number => text().withLength(min: 1, max: 10)();
  TextColumn get type => text().withLength(min: 1, max: 40)();

  /// Tarif de la nuit, en CENTS DE DOLLAR. C'est le prix annoncé au
  /// client, et donc la seule valeur saisie.
  ///
  /// Le franc reste la monnaie d'encaissement — la caisse, les dettes,
  /// les rapports sont en FC — mais il n'est plus la source : il se
  /// calcule au taux. Le tarif d'une chambre ne doit pas bouger parce
  /// que le franc a bougé.
  IntColumn get priceUsdCents => integer().withDefault(const Constant(0))();

  /// Le même tarif converti en francs, au taux courant.
  ///
  /// Valeur CALCULÉE, gardée en base parce que la caisse, le miroir et
  /// les rapports la lisent partout. Recalculée quand le tarif change et
  /// quand le taux change — voir `RoomsRepo.rafraichirConversions`.
  IntColumn get pricePerNightCents => integer()();
  IntColumn get status => intEnum<DbRoomStatus>()();
  TextColumn get currentGuest => text().nullable()();
  DateTimeColumn get checkoutDate => dateTime().nullable()();

  /// Note libre saisie au check-in (préférences client, motif du séjour,
  /// alertes, etc.). Vidée au checkOut. Affichée dans les rapports.
  TextColumn get checkinNote => text().nullable()();

  /// Horodatage précis du check-in (utilisé dans le rapport occupation).
  /// Set automatiquement par [RoomsRepo.checkIn], vidé au checkOut.
  DateTimeColumn get checkinAt => dateTime().nullable()();

  /// Séjour groupé : identifiant partagé par plusieurs chambres louées en
  /// même temps par une entreprise / un même payeur. Null = séjour solo.
  /// Vidé au checkOut. Permet de générer une facture consolidée.
  TextColumn get stayGroup => text().nullable()();

  /// Prise en charge : id du payeur (société ou particulier tiers). Null →
  /// c'est l'occupant qui paie lui-même. Vidé au checkOut.
  IntColumn get payerId => integer()
      .references(Payers, #id, onDelete: KeyAction.setNull)
      .nullable()();

  /// Photo de la chambre (chemin local ou URL Supabase Storage), même
  /// convention que Articles.imagePath. Null → icône générique.
  TextColumn get imagePath => text().nullable()();

  /// Tarif négocié pour le séjour en cours (cents FC/nuit). Null → on
  /// facture [pricePerNightCents] (tarif catalogue). L'écart entre les
  /// deux est reporté comme remise ligne à ligne sur la facture. Saisi
  /// au check-in, vidé au checkOut.
  IntColumn get negotiatedPriceCents => integer().nullable()();

  /// Le séjour en cours dans cette chambre (v27). Une vraie clé
  /// étrangère : c'est le séjour qui fait foi sur l'occupant, les dates et
  /// le tarif. Les champs « séjour en cours » ci-dessus restent remplis
  /// pour l'affichage et pour les postes pas encore à jour ; ils seront
  /// retirés dans une itération suivante.
  IntColumn get currentStayId => integer()
      .references(Stays, #id, onDelete: KeyAction.setNull)
      .nullable()();

  /// Changement local pas encore confirmé par le serveur (v29). Null =
  /// rien en attente.
  ///
  /// Tant qu'il est posé, la relecture du serveur ne touche pas à cette
  /// chambre : sans ce drapeau, un serveur en retard de quelques secondes
  /// — ou un envoi échoué — remettait « libre » une chambre qu'on venait
  /// d'occuper, et supprimait une chambre créée ici qui n'était pas
  /// encore arrivée là-bas.
  DateTimeColumn get pendingSince => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {number};
}

/// Fichier client (fidélité). Alimenté automatiquement dès qu'un client
/// est nommé au check-in ou sur une vente POS. Le téléphone sert de clé
/// stable pour dédupliquer.
class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fullName => text().withLength(min: 1, max: 120)();
  TextColumn get phone => text().nullable().unique()();
  TextColumn get email => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get firstSeenAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSeenAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get visitsCount => integer().withDefault(const Constant(0))();
  IntColumn get totalSpentCents => integer().withDefault(const Constant(0))();
}

/// Trace historique d'un séjour hôtelier après check-out. Persiste
/// toutes les données nécessaires pour régénérer la facture identique
/// depuis l'écran Historique (même après suppression du client, du
/// payeur ou de la chambre côté catalogue).
///
/// Un séjour peut couvrir 1 ou N chambres (cf. StayRooms).
class Stays extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get receiptNumber => text().withLength(min: 1, max: 40)();
  TextColumn get reservationNumber => text().nullable()();
  DateTimeColumn get generatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get checkinAt => dateTime()();
  DateTimeColumn get checkoutAt => dateTime()();
  // Occupant
  TextColumn get guestFullName => text()();
  TextColumn get guestNationality => text().nullable()();
  TextColumn get guestPhone => text().nullable()();
  TextColumn get guestEmail => text().nullable()();
  // Payeur (snapshot pour éviter les modifications rétroactives)
  TextColumn get payerName => text().nullable()();
  TextColumn get payerTaxId => text().nullable()();
  TextColumn get payerAddress => text().nullable()();
  TextColumn get payerContact => text().nullable()();
  // Facturation
  IntColumn get subtotalCents => integer()();

  /// Montant de la remise effectivement déduite (cents FC). Reste la
  /// source de vérité comptable — les 4 colonnes qui suivent ne servent
  /// qu'à expliquer *comment* ce montant a été obtenu.
  IntColumn get remiseCents => integer().withDefault(const Constant(0))();

  /// index de DiscountKind : 0 = montant fixe, 1 = pourcentage.
  IntColumn get remiseKind => integer().withDefault(const Constant(0))();

  /// Cents FC si remiseKind=0, centièmes de % si remiseKind=1 (1000 = 10 %).
  IntColumn get remiseValue => integer().withDefault(const Constant(0))();

  /// index de DiscountBase : 0 = hébergement seul, 1 = total avec extras.
  IntColumn get remiseBase => integer().withDefault(const Constant(1))();

  /// Motif du geste commercial ("Client fidèle", "Accord société"…).
  TextColumn get remiseReason => text().nullable()();
  IntColumn get acompteFcCents => integer().withDefault(const Constant(0))();
  IntColumn get acompteUsdCents => integer().withDefault(const Constant(0))();

  /// Taux FC pour 1 USD au moment du check-out, × 100.
  ///
  /// Figé, et c'est tout l'enjeu. `Currency.rate` est une valeur unique
  /// et COURANTE : une facture émise à 2300 et réimprimée à 2600
  /// annoncerait un total en dollars différent de celui que le client a
  /// payé. Un entier plutôt qu'un flottant : un taux est une donnée
  /// comptable, il ne s'arrondit pas au hasard des divisions.
  ///
  /// 0 = séjour antérieur à la bascule en dollars ; on retombe alors sur
  /// le taux courant, faute de mieux, et l'écran le dit.
  IntColumn get fcPerUsdCents => integer().withDefault(const Constant(0))();
  IntColumn get paymentMode => integer().withDefault(const Constant(0))();
  // Meta
  TextColumn get stayGroup => text().nullable()();
  TextColumn get serverLogin => text().nullable()();
  TextColumn get note => text().nullable()();
  // JSON sérialisé des extras (consommations liées aux chambres)
  TextColumn get extrasJson => text().withDefault(const Constant('[]'))();
  IntColumn get clientVisitsAtCheckout =>
      integer().withDefault(const Constant(0))();

  /// Identité du séjour sur tous les postes (même raison que les ventes :
  /// le serveur rangeait les séjours par numéro local).
  TextColumn get uid => text().nullable().clientDefault(nouvelUid)();

  /// Où en est le séjour. Les séjours d'avant la v27 n'existaient qu'une
  /// fois facturés : « facture » par défaut.
  IntColumn get statut => intEnum<DbStayStatus>()
      .withDefault(Constant(DbStayStatus.facture.index))();
}

/// Réservation future d'une ou plusieurs chambres. Distincte des séjours
/// (Stays) qui archivent les séjours passés. Une réservation qui débute
/// aujourd'hui peut être convertie en check-in — cf. RoomsRepo.checkIn
/// via ReservationsRepo.checkIn().
class Reservations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get reservationNumber =>
      text().withLength(min: 1, max: 40).unique()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get checkinDate => dateTime()();
  DateTimeColumn get checkoutDate => dateTime()();
  // Occupant / responsable de la réservation
  TextColumn get guestFullName => text()();
  TextColumn get guestPhone => text().nullable()();
  TextColumn get guestEmail => text().nullable()();
  // Prise en charge tiers (société)
  IntColumn get payerId => integer()
      .references(Payers, #id, onDelete: KeyAction.setNull)
      .nullable()();
  // Statut du cycle de vie
  IntColumn get status => intEnum<DbReservationStatus>()
      .withDefault(Constant(DbReservationStatus.confirmed.index))();
  // Acompte reçu à la réservation
  IntColumn get depositCents => integer().withDefault(const Constant(0))();
  // Métadonnées
  TextColumn get note => text().nullable()();
  TextColumn get createdByLogin => text().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get cancelReason => text().nullable()();
  // Lien vers le séjour créé au check-in (pour retrouver la facture).
  IntColumn get stayId => integer()
      .references(Stays, #id, onDelete: KeyAction.setNull)
      .nullable()();
}

/// Chambres associées à une réservation (peut réserver plusieurs
/// chambres en une seule opération, comme un check-in groupé).
class ReservationRooms extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get reservationId =>
      integer().references(Reservations, #id, onDelete: KeyAction.cascade)();
  TextColumn get roomNumber => text()();
  // Snapshot du prix au moment de la réservation (le prix peut changer
  // avant l'arrivée effective).
  IntColumn get pricePerNightCents => integer()();
}

/// Une chambre facturée dans un séjour donné. Snapshot du prix et du
/// type au moment du check-out (résistant aux changements de catalogue).
class StayRooms extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get stayId =>
      integer().references(Stays, #id, onDelete: KeyAction.cascade)();
  TextColumn get roomNumber => text()();
  TextColumn get roomType => text()();
  DateTimeColumn get checkinAt => dateTime()();
  DateTimeColumn get checkoutAt => dateTime()();

  /// Prix réellement facturé, en FRANCS (tarif négocié s'il y en avait
  /// un). Figé au check-out : c'est le montant encaissé.
  IntColumn get pricePerNightCents => integer()();

  /// Le même prix en CENTS DE DOLLAR, figé lui aussi.
  ///
  /// On garde les deux plutôt que de reconvertir à l'affichage : le taux
  /// bouge, et une facture réimprimée six mois plus tard doit annoncer
  /// le montant que le client a payé — pas ce qu'il vaudrait aujourd'hui.
  IntColumn get priceUsdCents => integer().withDefault(const Constant(0))();

  /// Tarif catalogue au moment du check-out. Null ou égal au prix
  /// facturé → aucun tarif négocié sur cette chambre.
  IntColumn get listPriceCents => integer().nullable()();

  /// Le tarif catalogue en dollars, pour afficher la remise dans la
  /// devise où elle a été négociée.
  IntColumn get listUsdCents => integer().nullable()();
  IntColumn get nights => integer()();

  /// Identité de la ligne sur tous les postes.
  TextColumn get uid => text().nullable().clientDefault(nouvelUid)();
}

/// Payeurs tiers (sociétés, ONG, ambassades…) qui prennent en charge un
/// séjour à la place de l'occupant. Un payeur peut aussi être une
/// personne physique distincte de l'occupant.
class Payers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  IntColumn get type => intEnum<DbPayerType>()
      .withDefault(const Constant(1))(); // company par défaut
  TextColumn get taxId => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get contact => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Mouvements de stock en attente d'envoi au serveur.
///
/// Le poste déclare une INTENTION — « −3 » — pas un résultat. Tant que
/// le mouvement n'est pas confirmé par le serveur, il reste ici.
///
/// C'est ce qui rend le hors-ligne viable : la caisse encaisse, le
/// mouvement s'inscrit, et il part dès que le réseau revient. L'ordre
/// d'arrivée n'a pas d'importance — additionner des deltas donne le même
/// résultat dans n'importe quel ordre.
class StockMoves extends Table {
  /// Identifiant généré ICI, avant tout envoi. C'est lui qui permet au
  /// serveur d'ignorer un doublon : une coupure juste après
  /// l'enregistrement serveur, mais avant l'accusé de réception, fait
  /// renvoyer le poste. Sans cette clé, le stock bougerait deux fois.
  TextColumn get opId => text()();

  IntColumn get articleId => integer()();

  /// Signé. Négatif pour une sortie, positif pour un ravitaillement.
  IntColumn get delta => integer()();

  /// « vente », « ravitaillement », « correction »… Remonte au serveur
  /// pour que le gérant sache d'où vient le mouvement.
  TextColumn get reason => text().nullable()();

  DateTimeColumn get occurredAt => dateTime().withDefault(currentDateAndTime)();

  /// Null tant que le serveur ne l'a pas confirmé.
  DateTimeColumn get sentAt => dateTime().nullable()();

  /// Nombre d'échecs d'envoi. Sert à espacer les tentatives plutôt qu'à
  /// marteler un serveur injoignable.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Dernier refus du serveur, quand il y en a un. Affiché au gérant :
  /// un mouvement bloqué ne doit jamais disparaître en silence.
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {opId};
}

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get soldAt => dateTime()();
  IntColumn get serverUserId => integer()
      .references(Users, #id, onDelete: KeyAction.setNull)
      .nullable()();
  IntColumn get payment => intEnum<DbPayment>()();
  // Emplacement de la vente (restaurant / terrasse / hôtel).
  IntColumn get location =>
      intEnum<DbLocation>().withDefault(const Constant(0))();
  // Nom du client, optionnel — apparaît sur la facture si renseigné.
  TextColumn get customerName => text().nullable()();
  // Chambre rattachée (optionnel) — "M. John · Chambre 4".
  TextColumn get roomNumber => text().nullable()();
  // Dette : vente enregistrée impayée. settledAt = date de règlement (null
  // tant que la dette est en cours).
  BoolColumn get onCredit => boolean().withDefault(const Constant(false))();
  DateTimeColumn get settledAt => dateTime().nullable()();
  TextColumn get note => text().nullable()();

  // ── Accusé de réception du serveur ──────────────────────────────────
  //
  // Sans ces trois colonnes, on ne pouvait pas répondre à la seule
  // question qui compte : « cette vente est-elle en lieu sûr ? ».
  // L'application poussait chaque vente en oubliant aussitôt le
  // résultat, et se rattrapait en repoussant TOUT toutes les dix
  // minutes — 21 Mo par jour pour 207 ventes, et une facture qui grandit
  // avec l'historique. Le jour où ce renvoi dépasserait le délai
  // d'attente, il échouerait en silence et les pertes commenceraient
  // là, sans que rien ne le signale.

  /// Quand le serveur a confirmé. Null = pas encore en ligne.
  DateTimeColumn get syncedAt => dateTime().nullable()();

  /// Tentatives infructueuses. Sert à espacer les renvois.
  IntColumn get syncAttempts => integer().withDefault(const Constant(0))();

  /// Pourquoi la dernière tentative a échoué. Gardé en clair : c'est la
  /// première chose qu'on regarde quand une caisse ne remonte plus.
  TextColumn get syncError => text().nullable()();

  /// Le séjour sur lequel cette consommation a été mise (v27). Remplace
  /// le rapprochement par numéro de chambre tapé, qui ne distinguait pas
  /// deux clients successifs de la même chambre. Null pour une vente
  /// ordinaire, ou reçue d'un autre poste.
  IntColumn get stayId => integer()
      .references(Stays, #id, onDelete: KeyAction.setNull)
      .nullable()();

  /// Identité de la vente sur tous les postes (cf. core/identite.dart).
  /// `id` reste le numéro du ticket sur CE poste ; le serveur, lui, ne
  /// connaît la vente que par cet identifiant.
  ///
  /// Nullable pour pouvoir être ajouté à une base existante ; rempli à
  /// chaque insertion, et à l'ouverture pour les ventes plus anciennes.
  TextColumn get uid => text().nullable().clientDefault(nouvelUid)();
}

/// Règlements reçus sur une vente à crédit.
///
/// Pourquoi une table, et pas une colonne `montantPaye` sur la vente :
/// une dette se rembourse en plusieurs fois, et chaque versement est un
/// fait daté — qui a encaissé, combien, comment. Écraser un cumul
/// perdrait tout ça, et rendrait impossible de répondre à la seule
/// question qui compte quand un client conteste : « quand ai-je payé,
/// et à qui ? »
///
/// La vente reste soldée par `Sales.settledAt`, posé quand le cumul des
/// versements atteint le total. Les deux ne se contredisent jamais :
/// `settledAt` est un résumé, ces lignes sont la source.
class DebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId =>
      integer().references(Sales, #id, onDelete: KeyAction.cascade)();

  /// Montant reçu, en cents. Toujours strictement positif : un
  /// remboursement au client s'enregistre comme une autre opération, pas
  /// comme un versement négatif qu'on oublierait de lire.
  IntColumn get amountCents => integer()();
  IntColumn get payment => intEnum<DbPayment>()();
  DateTimeColumn get receivedAt => dateTime().withDefault(currentDateAndTime)();

  /// Qui a encaissé. Conservé en clair : un compte peut être supprimé,
  /// la trace du versement doit lui survivre.
  TextColumn get receivedByLogin => text().nullable()();
  TextColumn get note => text().nullable()();
}

class SaleLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId =>
      integer().references(Sales, #id, onDelete: KeyAction.cascade)();
  IntColumn get articleId => integer()
      .references(Articles, #id, onDelete: KeyAction.setNull)
      .nullable()();
  TextColumn get articleName => text()(); // snapshot au moment de la vente
  IntColumn get qty => integer()();
  IntColumn get unitPriceCents => integer()();

  /// Identité de la ligne sur tous les postes (même raison que
  /// [Sales.uid] : les numéros de ligne aussi se chevauchaient).
  TextColumn get uid => text().nullable().clientDefault(nouvelUid)();
}
