import 'package:drift/drift.dart';

// Enums stockés en index int (sqlite n'a pas de vrai enum).
// L'ordre doit rester stable — ne jamais réordonner.

enum DbUserRole { superAdmin, admin, serveur }
enum DbCategory { boissons, nourriture, chambres }
enum DbRoomStatus { libre, occupee, nettoyage, maintenance }
enum DbPayment { cash, card, mobileMoney }
enum DbLocation { restaurant, terrasse, hotel }

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
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastLogin => dateTime().nullable()();
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
}

class Rooms extends Table {
  TextColumn get number => text().withLength(min: 1, max: 10)();
  TextColumn get type => text().withLength(min: 1, max: 40)();
  IntColumn get pricePerNightCents => integer()();
  IntColumn get status => intEnum<DbRoomStatus>()();
  TextColumn get currentGuest => text().nullable()();
  DateTimeColumn get checkoutDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {number};
}

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get soldAt => dateTime()();
  IntColumn get serverUserId =>
      integer().references(Users, #id, onDelete: KeyAction.setNull).nullable()();
  IntColumn get payment => intEnum<DbPayment>()();
  // Emplacement de la vente (restaurant / terrasse / hôtel).
  IntColumn get location =>
      intEnum<DbLocation>().withDefault(const Constant(0))();
  // Nom du client, optionnel — apparaît sur la facture si renseigné.
  TextColumn get customerName => text().nullable()();
  TextColumn get note => text().nullable()();
}

class SaleLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId =>
      integer().references(Sales, #id, onDelete: KeyAction.cascade)();
  IntColumn get articleId =>
      integer().references(Articles, #id, onDelete: KeyAction.setNull).nullable()();
  TextColumn get articleName => text()(); // snapshot au moment de la vente
  IntColumn get qty => integer()();
  IntColumn get unitPriceCents => integer()();
}
