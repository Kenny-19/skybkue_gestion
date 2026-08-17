import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart';

import 'database.dart';
import 'schema.dart';

// ─── Users ──────────────────────────────────────────────────────────────

class UsersRepo {
  UsersRepo(this._db);
  final AppDatabase _db;

  Stream<List<User>> watchAll() => _db.select(_db.users).watch();

  Future<int> create({
    required String fullName,
    required String login,
    required String password,
    required DbUserRole role,
  }) {
    return _db.into(_db.users).insert(UsersCompanion.insert(
          fullName: fullName,
          login: login,
          passwordHash: BCrypt.hashpw(password, BCrypt.gensalt()),
          role: role,
        ));
  }

  Future<void> setActive(int id, bool active) {
    return (_db.update(_db.users)..where((u) => u.id.equals(id)))
        .write(UsersCompanion(active: Value(active)));
  }

  Future<void> resetPassword(int id, String newPassword) {
    return (_db.update(_db.users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(
          passwordHash: Value(BCrypt.hashpw(newPassword, BCrypt.gensalt()))),
    );
  }

  Future<void> rename(int id, String fullName) {
    return (_db.update(_db.users)..where((u) => u.id.equals(id)))
        .write(UsersCompanion(fullName: Value(fullName)));
  }
}

// ─── Articles ───────────────────────────────────────────────────────────

class ArticlesRepo {
  ArticlesRepo(this._db);
  final AppDatabase _db;

  Stream<List<Article>> watchActive() =>
      (_db.select(_db.articles)..where((a) => a.active.equals(true))).watch();

  Future<List<Article>> allActive() =>
      (_db.select(_db.articles)..where((a) => a.active.equals(true))).get();

  Future<int> create({
    required String name,
    required int priceCents,
    required DbCategory category,
    String? imagePath,
    bool trackStock = false,
    String unit = 'unité',
    int stockQty = 0,
    int threshold = 0,
  }) {
    return _db.into(_db.articles).insert(ArticlesCompanion.insert(
          name: name,
          priceCents: priceCents,
          category: category,
          imagePath: Value(imagePath),
          trackStock: Value(trackStock),
          unit: Value(unit),
          stockQty: Value(stockQty),
          threshold: Value(threshold),
        ));
  }

  Future<void> update({
    required int id,
    required String name,
    required int priceCents,
    required DbCategory category,
    String? imagePath,
    required bool trackStock,
    required String unit,
    required int stockQty,
    required int threshold,
  }) {
    return (_db.update(_db.articles)..where((a) => a.id.equals(id))).write(
      ArticlesCompanion(
        name: Value(name),
        priceCents: Value(priceCents),
        category: Value(category),
        imagePath: Value(imagePath),
        trackStock: Value(trackStock),
        unit: Value(unit),
        stockQty: Value(stockQty),
        threshold: Value(threshold),
      ),
    );
  }

  /// Ajuste la quantité en stock (delta +/-, jamais négatif).
  Future<void> adjustQty(int id, int delta) async {
    final art = await (_db.select(_db.articles)..where((a) => a.id.equals(id)))
        .getSingle();
    final newQty = art.stockQty + delta;
    await (_db.update(_db.articles)..where((a) => a.id.equals(id)))
        .write(ArticlesCompanion(stockQty: Value(newQty < 0 ? 0 : newQty)));
  }

  Future<void> deactivate(int id) {
    return (_db.update(_db.articles)..where((a) => a.id.equals(id)))
        .write(const ArticlesCompanion(active: Value(false)));
  }
}

// ─── Rooms ──────────────────────────────────────────────────────────────

class RoomsRepo {
  RoomsRepo(this._db);
  final AppDatabase _db;

  Stream<List<Room>> watchAll() {
    final query = _db.select(_db.rooms)..orderBy([(r) => OrderingTerm.asc(r.number)]);
    return query.watch();
  }

  Future<void> checkIn(String number, String guest, DateTime checkout) {
    return (_db.update(_db.rooms)..where((r) => r.number.equals(number))).write(
      RoomsCompanion(
        status: const Value(DbRoomStatus.occupee),
        currentGuest: Value(guest),
        checkoutDate: Value(checkout),
      ),
    );
  }

  Future<void> checkOut(String number) {
    return (_db.update(_db.rooms)..where((r) => r.number.equals(number))).write(
      const RoomsCompanion(
        status: Value(DbRoomStatus.nettoyage),
        currentGuest: Value(null),
        checkoutDate: Value(null),
      ),
    );
  }

  Future<void> setStatus(String number, DbRoomStatus status) {
    return (_db.update(_db.rooms)..where((r) => r.number.equals(number)))
        .write(RoomsCompanion(status: Value(status)));
  }

  Future<void> create({
    required String number,
    required String type,
    required int pricePerNightCents,
  }) {
    return _db.into(_db.rooms).insert(RoomsCompanion.insert(
          number: number,
          type: type,
          pricePerNightCents: pricePerNightCents,
          status: DbRoomStatus.libre,
        ));
  }

  Future<void> updateInfo({
    required String number,
    required String type,
    required int pricePerNightCents,
  }) {
    return (_db.update(_db.rooms)..where((r) => r.number.equals(number))).write(
      RoomsCompanion(
        type: Value(type),
        pricePerNightCents: Value(pricePerNightCents),
      ),
    );
  }

  Future<void> delete(String number) {
    return (_db.delete(_db.rooms)..where((r) => r.number.equals(number))).go();
  }
}

// ─── Sales ──────────────────────────────────────────────────────────────

class SaleWithLines {
  final Sale sale;
  final List<SaleLine> lines;
  final User? server;
  SaleWithLines(this.sale, this.lines, this.server);

  int get totalCents => lines.fold(0, (s, l) => s + l.qty * l.unitPriceCents);
  int get itemsCount => lines.fold(0, (s, l) => s + l.qty);
}

class SalesRepo {
  SalesRepo(this._db);
  final AppDatabase _db;

  Stream<List<SaleWithLines>> watchRecent({int days = 7}) {
    final since = DateTime.now().subtract(Duration(days: days));
    final query = _db.select(_db.sales)
      ..where((s) => s.soldAt.isBiggerOrEqualValue(since))
      ..orderBy([(s) => OrderingTerm.desc(s.soldAt)]);
    return query.watch().asyncMap(_hydrate);
  }

  Future<List<SaleWithLines>> _hydrate(List<Sale> sales) async {
    if (sales.isEmpty) return [];
    final ids = sales.map((s) => s.id).toList();
    final userIds =
        sales.map((s) => s.serverUserId).whereType<int>().toSet().toList();

    final lines = await (_db.select(_db.saleLines)
          ..where((l) => l.saleId.isIn(ids)))
        .get();
    final users = userIds.isEmpty
        ? <User>[]
        : await (_db.select(_db.users)..where((u) => u.id.isIn(userIds))).get();

    final linesBySale = <int, List<SaleLine>>{};
    for (final l in lines) {
      linesBySale.putIfAbsent(l.saleId, () => []).add(l);
    }
    final userById = {for (final u in users) u.id: u};

    return sales
        .map((s) => SaleWithLines(
              s,
              linesBySale[s.id] ?? const [],
              s.serverUserId == null ? null : userById[s.serverUserId!],
            ))
        .toList();
  }

  Future<int> createSale({
    required Map<int, int> articleQuantities, // articleId -> qty
    required DbPayment payment,
    required DbLocation location,
    required int? serverUserId,
    String? customerName,
    String? note,
  }) async {
    return _db.transaction(() async {
      final saleId = await _db.into(_db.sales).insert(SalesCompanion.insert(
            soldAt: DateTime.now(),
            payment: payment,
            location: Value(location),
            serverUserId: Value(serverUserId),
            customerName: Value(customerName),
            note: Value(note),
          ));
      for (final entry in articleQuantities.entries) {
        final art = await (_db.select(_db.articles)
              ..where((a) => a.id.equals(entry.key)))
            .getSingle();
        await _db.into(_db.saleLines).insert(SaleLinesCompanion.insert(
              saleId: saleId,
              articleId: Value(art.id),
              articleName: art.name,
              qty: entry.value,
              unitPriceCents: art.priceCents,
            ));
        // Décrément direct du stock si le produit est suivi.
        if (art.trackStock) {
          final newQty = art.stockQty - entry.value;
          await (_db.update(_db.articles)..where((a) => a.id.equals(art.id)))
              .write(ArticlesCompanion(stockQty: Value(newQty < 0 ? 0 : newQty)));
        }
      }
      return saleId;
    });
  }
}

// ─── Agrégations (dashboard) ────────────────────────────────────────────

class DailyTotal {
  final DateTime day;
  final int boissonsCents;
  final int nourritureCents;
  final int chambresCents;
  final int count;
  const DailyTotal({
    required this.day,
    required this.boissonsCents,
    required this.nourritureCents,
    required this.chambresCents,
    required this.count,
  });
  int get totalCents => boissonsCents + nourritureCents + chambresCents;
}

class MetricsRepo {
  MetricsRepo(this._db);
  final AppDatabase _db;

  Stream<List<DailyTotal>> watchLast7Days() {
    return _db.select(_db.sales).watch().asyncMap((_) => _computeLast7Days());
  }

  Future<List<DailyTotal>> _computeLast7Days() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));

    final sales = await (_db.select(_db.sales)
          ..where((s) => s.soldAt.isBiggerOrEqualValue(start)))
        .get();
    if (sales.isEmpty) {
      return List.generate(
          7,
          (i) => DailyTotal(
              day: start.add(Duration(days: i)),
              boissonsCents: 0,
              nourritureCents: 0,
              chambresCents: 0,
              count: 0));
    }

    final ids = sales.map((s) => s.id).toList();
    final lines =
        await (_db.select(_db.saleLines)..where((l) => l.saleId.isIn(ids))).get();
    final articles = await _db.select(_db.articles).get();
    final catById = {for (final a in articles) a.id: a.category};

    final buckets = <DateTime, DailyTotal>{
      for (int i = 0; i < 7; i++)
        start.add(Duration(days: i)): DailyTotal(
            day: start.add(Duration(days: i)),
            boissonsCents: 0,
            nourritureCents: 0,
            chambresCents: 0,
            count: 0),
    };

    final byDay = <DateTime, List<Sale>>{};
    for (final s in sales) {
      final d = DateTime(s.soldAt.year, s.soldAt.month, s.soldAt.day);
      byDay.putIfAbsent(d, () => []).add(s);
    }

    for (final e in byDay.entries) {
      if (!buckets.containsKey(e.key)) continue;
      int b = 0, n = 0, c = 0;
      for (final sale in e.value) {
        for (final line in lines.where((l) => l.saleId == sale.id)) {
          final cat = line.articleId == null ? null : catById[line.articleId];
          final total = line.qty * line.unitPriceCents;
          switch (cat) {
            case DbCategory.boissons:
              b += total;
              break;
            case DbCategory.nourriture:
              n += total;
              break;
            case DbCategory.chambres:
              c += total;
              break;
            case null:
              n += total;
              break;
          }
        }
      }
      buckets[e.key] = DailyTotal(
        day: e.key,
        boissonsCents: b,
        nourritureCents: n,
        chambresCents: c,
        count: e.value.length,
      );
    }
    final result = buckets.values.toList()..sort((a, b) => a.day.compareTo(b.day));
    return result;
  }
}
