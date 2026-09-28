import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../core/auth.dart';
import '../core/cloud_config.dart';
import '../core/temps.dart';
import '../data/database.dart';
import '../data/schema.dart';
import '../core/horloge.dart';
import 'ventes_outbox.dart';

/// Miroir des données locales vers Supabase (sens unique : local = maître).
///
/// Permet de consulter les ventes/produits dans le dashboard Supabase même si
/// l'app locale plante. Chaque écriture importante est repoussée vers des
/// tables `mirror_*`. Hors ligne → ignoré (les données restent en local, une
/// synchro complète les rattrapera).
/// Résultat structuré d'une synchronisation complète (syncAll).
/// Chaque table est traitée indépendamment ; une table qui échoue
/// n'empêche pas les autres. Les erreurs sont collectées ici pour
/// affichage dans la sidebar / diagnostic.
class SyncResult {
  final DateTime at;
  final Map<String, int> pushed; // table → nombre d'items poussés
  final List<String> errors; // erreurs par table ("clients: …")
  final bool cloudConfigured;

  const SyncResult({
    required this.at,
    required this.pushed,
    required this.errors,
    required this.cloudConfigured,
  });

  bool get ok => errors.isEmpty && cloudConfigured;
  int get totalPushed => pushed.values.fold(0, (a, b) => a + b);

  String get summary {
    if (!cloudConfigured) return 'Cloud non configuré';
    if (ok) return '$totalPushed élément(s) synchronisé(s)';
    return '$totalPushed OK · ${errors.length} erreur(s)';
  }
}

/// Résultat détaillé d'une restauration depuis les tables miroir.
class MirrorRestoreResult {
  final bool ok;
  final String message;
  final int articles;
  final int rooms;
  final int sales;
  final int lines;
  final int users;
  const MirrorRestoreResult({
    required this.ok,
    required this.message,
    this.articles = 0,
    this.rooms = 0,
    this.sales = 0,
    this.lines = 0,
    this.users = 0,
  });

  String get summary => ok
      ? '$sales ventes · $articles produits · $rooms chambres · $users comptes'
      : message;
}

class MirrorService {
  MirrorService._();

  static bool get _enabled => CloudConfig.isConfigured;

  static SupabaseClient? get _c {
    if (!_enabled) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static final AppDatabase _db = AppDatabase.instance;

  // ─── Push incrémental d'une vente ────────────────────────────────────

  /// Pousse une vente, en LEVANT si ça échoue.
  ///
  /// C'est la version qu'utilise la file d'attente : elle a besoin de
  /// savoir. La variante silencieuse ci-dessous existe pour les appels
  /// qui ne doivent jamais faire échouer une opération de caisse.
  static Future<void> pushSaleOrThrow(int saleId) async {
    final c = _c;
    if (c == null) throw StateError('Cloud non configuré');
    final sale = await (_db.select(_db.sales)
          ..where((s) => s.id.equals(saleId)))
        .getSingleOrNull();
    if (sale == null) return;
    final lines = await (_db.select(_db.saleLines)
          ..where((l) => l.saleId.equals(saleId)))
        .get();

    final deja = await _dejaPayeParVente([saleId]);
    await c.from('mirror_sales').upsert(
        _saleJson(sale, dejaPaye: deja[saleId] ?? 0),
        onConflict: 'id');
    if (lines.isNotEmpty) {
      await c
          .from('mirror_sale_lines')
          .upsert(lines.map(_lineJson).toList(), onConflict: 'id');
    }
  }

  /// Pousse un séjour facturé et ses chambres vers le miroir.
  ///
  /// Appelé juste après un check-out. C'est ce qui manquait pour que le
  /// tableau de bord de Pamela affiche un chiffre d'affaires hôtel : les
  /// sérialiseurs existaient depuis des mois, mais personne ne les
  /// appelait et les tables n'existaient pas.
  ///
  /// Best-effort, comme les ventes : un réseau absent ne doit jamais
  /// empêcher de libérer une chambre. Le séjour reste en base locale et
  /// repartira au prochain `syncAll`.
  static Future<void> pushStayById(int stayId) async {
    final c = _c;
    if (c == null) return;
    try {
      final stay = await (_db.select(_db.stays)
            ..where((s) => s.id.equals(stayId)))
          .getSingleOrNull();
      if (stay == null) return;
      final rooms = await (_db.select(_db.stayRooms)
            ..where((r) => r.stayId.equals(stayId)))
          .get();

      await c.from('mirror_stays').upsert(_stayJson(stay), onConflict: 'id');
      if (rooms.isNotEmpty) {
        await c
            .from('mirror_stay_rooms')
            .upsert(rooms.map(_stayRoomJson).toList(), onConflict: 'id');
      }
    } catch (_) {
      // best-effort
    }
  }

  // ─── Restauration : miroir Supabase → BDD locale ────────────────────

  /// Résultat détaillé d'une restauration miroir.
  static Future<MirrorRestoreResult> restoreFromMirror() async {
    final c = _c;
    if (c == null) {
      return const MirrorRestoreResult(
          ok: false, message: 'Cloud non configuré');
    }
    try {
      // 1. Fetch de toutes les tables miroir en parallèle.
      final results = await Future.wait([
        c.from('mirror_articles').select(),
        c.from('mirror_rooms').select(),
        c.from('mirror_sales').select(),
        c.from('mirror_sale_lines').select(),
        c.from('mirror_users').select(),
      ]);
      final articles = (results[0] as List).cast<Map<String, dynamic>>();
      final rooms = (results[1] as List).cast<Map<String, dynamic>>();
      final sales = (results[2] as List).cast<Map<String, dynamic>>();
      final lines = (results[3] as List).cast<Map<String, dynamic>>();
      final users = (results[4] as List).cast<Map<String, dynamic>>();

      // 2. Écriture atomique côté local — soit tout, soit rien.
      await _db.transaction(() async {
        // Snapshot des users locaux — utilisé plus bas pour matcher par login
        // (le miroir peut avoir des ids différents), afin de préserver le
        // passwordHash quand un compte du miroir existe déjà en local.
        final existingUsers = await _db.select(_db.users).get();

        // Wipe des tables métier (users : merge ci-dessous, jamais wipe).
        await _db.delete(_db.saleLines).go();
        await _db.delete(_db.sales).go();
        await _db.delete(_db.articles).go();
        await _db.delete(_db.rooms).go();

        // Users : merge par LOGIN (case-insensitive). On construit aussi
        // un mapping mirrorUserId → localUserId pour remapper
        // `sales.serverUserId` plus bas (les ids miroir peuvent différer
        // des ids locaux).
        //
        // Le miroir pouvait contenir plusieurs rows pour un même login
        // (bug pré-fix de onConflict='id') — on dédup côté client en
        // gardant la dernière occurrence, matching case-insensitive.
        final existingByLogin = {
          for (final u in existingUsers) u.login.toLowerCase(): u
        };
        final userIdMap = <int, int>{};
        // Dédup mirror : garder la dernière ligne rencontrée par login.
        final dedupedUsers = <String, Map<String, dynamic>>{};
        for (final u in users) {
          dedupedUsers[(u['login'] as String).toLowerCase()] = u;
        }
        for (final u in dedupedUsers.values) {
          final mirrorId = (u['id'] as num).toInt();
          final login = u['login'] as String;
          final loginLc = login.toLowerCase();
          final fullName = u['full_name'] as String;
          final role = DbUserRole.values[(u['role'] as num).toInt()];
          final active = (u['active'] as bool?) ?? true;
          final lastLogin = _parseDate(u['last_login']);
          final existing = existingByLogin[loginLc];
          if (existing != null) {
            await (_db.update(_db.users)
                  ..where((x) => x.id.equals(existing.id)))
                .write(UsersCompanion(
              fullName: Value(fullName),
              role: Value(role),
              active: Value(active),
              lastLogin: Value(lastLogin),
            ));
            userIdMap[mirrorId] = existing.id;
          } else {
            // JAMAIS de hash aléatoire ici. Le miroir ne contient pas
            // les mots de passe : un faux hash « bien formé » produit un
            // compte qui a l'air normal mais dont AUCUN mot de passe ne
            // marchera jamais — l'utilisateur croit se tromper de code
            // et se retrouve enfermé dehors sans explication.
            // La sentinelle, elle, est reconnue : l'écran Comptes
            // affiche « jamais connecté ici » et la connexion dit
            // clairement qu'il faut se connecter une fois avec Internet.
            const hash = kNoOfflineAccessHash;
            // insertOnConflictUpdate : filet défensif si un login
            // casse-differente existe déjà en local sans qu'on l'ait
            // vu au SELECT (race ou collation surprenante).
            final newLocalId = await _db.into(_db.users).insertOnConflictUpdate(
                  UsersCompanion.insert(
                    fullName: fullName,
                    login: login,
                    passwordHash: hash,
                    role: role,
                    active: Value(active),
                    createdAt:
                        Value(_parseDate(u['created_at']) ?? Horloge.maintenant()),
                    lastLogin: Value(lastLogin),
                  ),
                );
            userIdMap[mirrorId] = newLocalId;
          }
        }

        // Articles — on préserve l'id miroir (table wipée juste au-dessus,
        // donc aucun conflit possible). Indispensable pour que les FK
        // sale_lines.article_id restent valides.
        for (final a in articles) {
          await _db.into(_db.articles).insert(
                ArticlesCompanion.insert(
                  id: Value((a['id'] as num).toInt()),
                  name: a['name'] as String,
                  priceCents: (a['price_cents'] as num).toInt(),
                  category: DbCategory.values[(a['category'] as num).toInt()],
                  imagePath: Value(a['image_path'] as String?),
                  active: Value((a['active'] as bool?) ?? true),
                  trackStock: Value((a['track_stock'] as bool?) ?? false),
                  unit: Value((a['unit'] as String?) ?? 'unité'),
                  stockQty: Value(((a['stock_qty'] as num?) ?? 0).toInt()),
                  threshold: Value(((a['threshold'] as num?) ?? 0).toInt()),
                ),
              );
        }

        // Chambres — PK = number, pas d'auto-increment à gérer.
        for (final r in rooms) {
          await _db.into(_db.rooms).insert(
                RoomsCompanion.insert(
                  number: r['number'] as String,
                  type: r['type'] as String,
                  pricePerNightCents:
                      (r['price_per_night_cents'] as num).toInt(),
                  status: DbRoomStatus.values[(r['status'] as num).toInt()],
                  currentGuest: Value(r['current_guest'] as String?),
                  checkoutDate: Value(_parseDate(r['checkout_date'])),
                  checkinNote: Value(r['checkin_note'] as String?),
                  checkinAt: Value(_parseDate(r['checkin_at'])),
                  stayGroup: Value(r['stay_group'] as String?),
                  imagePath: Value(r['image_path'] as String?),
                  negotiatedPriceCents:
                      Value((r['negotiated_price_cents'] as num?)?.toInt()),
                ),
              );
        }

        // Ventes — on préserve l'id miroir + on remappe le serverUserId
        // via userIdMap. Un miroir user_id qui ne matche aucun login
        // local → null (le lien serveur est perdu mais la vente reste).
        for (final s in sales) {
          final mirrorServerId = (s['server_user_id'] as num?)?.toInt();
          final localServerId =
              mirrorServerId == null ? null : userIdMap[mirrorServerId];
          await _db.into(_db.sales).insert(
                SalesCompanion.insert(
                  id: Value((s['id'] as num).toInt()),
                  soldAt: _parseDate(s['sold_at']) ?? Horloge.maintenant(),
                  serverUserId: Value(localServerId),
                  payment: DbPayment.values[(s['payment'] as num).toInt()],
                  location:
                      Value(DbLocation.values[(s['location'] as num).toInt()]),
                  customerName: Value(s['customer_name'] as String?),
                  roomNumber: Value(s['room_number'] as String?),
                  onCredit: Value((s['on_credit'] as bool?) ?? false),
                  settledAt: Value(_parseDate(s['settled_at'])),
                  note: Value(s['note'] as String?),
                ),
              );
        }

        // Lignes de vente — sale_id et article_id ont leurs ids miroir
        // préservés ci-dessus, les FK restent valides.
        for (final l in lines) {
          await _db.into(_db.saleLines).insert(
                SaleLinesCompanion.insert(
                  saleId: (l['sale_id'] as num).toInt(),
                  articleId: Value((l['article_id'] as num?)?.toInt()),
                  articleName: l['article_name'] as String,
                  qty: (l['qty'] as num).toInt(),
                  unitPriceCents: (l['unit_price_cents'] as num).toInt(),
                ),
              );
        }
      });

      return MirrorRestoreResult(
        ok: true,
        message: 'Restauration réussie',
        articles: articles.length,
        rooms: rooms.length,
        sales: sales.length,
        lines: lines.length,
        users: users.length,
      );
    } catch (e) {
      return MirrorRestoreResult(ok: false, message: 'Échec : $e');
    }
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  // ─── Push / delete d'une chambre (multi-postes) ────────────────────

  /// Pousse une chambre vers `mirror_rooms` — à appeler après chaque
  /// mutation locale (create / update / checkIn / checkOut / setStatus)
  /// pour que les autres postes voient l'état à jour au prochain pull.
  static Future<void> pushRoomByNumber(String number) async {
    final c = _c;
    if (c == null) return;
    try {
      final r = await (_db.select(_db.rooms)
            ..where((x) => x.number.equals(number)))
          .getSingleOrNull();
      if (r == null) return;
      await c.from('mirror_rooms').upsert(_roomJson(r), onConflict: 'number');
    } catch (_) {}
  }

  /// Propage la suppression d'une chambre côté miroir.
  static Future<void> deleteRoomByNumber(String number) async {
    final c = _c;
    if (c == null) return;
    try {
      await c.from('mirror_rooms').delete().eq('number', number);
    } catch (_) {}
  }

  // ─── Comptes utilisateurs : plus de miroir ─────────────────────────
  //
  // Les comptes ne transitent plus par `mirror_users` : ils vivent dans
  // `app_users` côté Supabase et sont manipulés par AccountsService, qui
  // ne laisse jamais descendre le hash du mot de passe sur le poste.
  // Ces fonctions restent en place, inertes, parce qu'elles sont encore
  // appelées par d'anciens chemins (restauration de sauvegarde).

  @Deprecated('Les comptes passent par AccountsService / app_users.')
  static Future<void> pushUserById(int id) async {}

  @Deprecated('Les comptes passent par AccountsService / app_users.')
  static Future<void> deleteUserById(int id) async {}

  @Deprecated('Les comptes passent par AccountsService / app_users.')
  static Future<void> deleteUserByLogin(String login) async {}

  // ─── Pull des chambres / users (autres postes → poste courant) ─────

  /// Récupère toutes les chambres du miroir et fusionne dans la BDD locale
  /// (upsert par `number`, delete des chambres locales absentes du miroir).
  /// Best-effort : silencieux hors ligne. Renvoie le nombre appliqué.
  static Future<int> pullRoomsIntoLocal() async {
    final c = _c;
    if (c == null) return 0;
    try {
      final remote = await c.from('mirror_rooms').select();
      final rows = (remote as List).cast<Map<String, dynamic>>();
      final remoteNumbers = rows.map((r) => r['number'] as String).toSet();

      await _db.transaction(() async {
        for (final r in rows) {
          final companion = RoomsCompanion.insert(
            number: r['number'] as String,
            type: r['type'] as String,
            pricePerNightCents: (r['price_per_night_cents'] as num).toInt(),
            // Un ZÉRO serveur n'écrase JAMAIS un tarif local.
            //
            // Ce n'est pas une précaution théorique : le 22 septembre, la
            // migration a converti 19 chambres en dollars, et le pull a
            // remis 0 partout dans les quinze secondes — la colonne
            // venait d'être créée côté serveur avec `default 0`, et le
            // poste l'a adoptée comme si elle faisait foi.
            //
            // Même mécanisme que l'incident du stock en septembre : une
            // valeur calculée localement, effacée par une valeur serveur
            // qui n'était pas encore renseignée. Tant que le serveur n'a
            // rien à dire, il ne dit rien.
            priceUsdCents: _entier(r['price_usd_cents']) > 0
                ? Value(_entier(r['price_usd_cents']))
                : const Value.absent(),
            status: DbRoomStatus.values[(r['status'] as num).toInt()],
            currentGuest: Value(r['current_guest'] as String?),
            checkoutDate: Value(_parseDate(r['checkout_date'])),
            checkinNote: Value(r['checkin_note'] as String?),
            checkinAt: Value(_parseDate(r['checkin_at'])),
            stayGroup: Value(r['stay_group'] as String?),
            payerId: Value((r['payer_id'] as num?)?.toInt()),
            imagePath: Value(r['image_path'] as String?),
            negotiatedPriceCents:
                Value((r['negotiated_price_cents'] as num?)?.toInt()),
          );
          await _db.into(_db.rooms).insertOnConflictUpdate(companion);
        }
        // Delete des chambres locales qui n'existent plus côté miroir.
        final localAll = await _db.select(_db.rooms).get();
        for (final l in localAll) {
          if (!remoteNumbers.contains(l.number)) {
            await (_db.delete(_db.rooms)
                  ..where((x) => x.number.equals(l.number)))
                .go();
          }
        }
      });
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  /// Rapatrie l'historique de l'hôtel depuis le serveur.
  ///
  /// Les séjours PARTAIENT vers `mirror_stays` sans que personne ne les
  /// relise : chaque poste ne voyait que les check-out qu'il avait
  /// lui-même enregistrés. Un gérant à distance, ou une réception qui
  /// prend la relève sur un autre poste, travaillait sur un historique
  /// amputé sans aucun signe que quelque chose manquait.
  ///
  /// Sens unique, du serveur vers le poste. On n'efface JAMAIS un séjour
  /// local absent du serveur : ce serait supprimer une facture émise
  /// parce qu'une synchronisation n'est pas encore passée. Les chambres
  /// peuvent se permettre cette suppression — leur vérité est l'état
  /// courant. Un séjour, lui, est un fait comptable.
  static Future<int> pullStaysIntoLocal({int limite = 500}) async {
    final c = _c;
    if (c == null) return 0;
    try {
      final remote = await c
          .from('mirror_stays')
          .select()
          .order('checkout_at', ascending: false)
          .limit(limite);
      final rows = (remote as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return 0;

      final ids = rows.map((r) => (r['id'] as num).toInt()).toList();
      final chambres = await c
          .from('mirror_stay_rooms')
          .select()
          .inFilter('stay_id', ids);
      final lignes = (chambres as List).cast<Map<String, dynamic>>();

      await _db.transaction(() async {
        for (final r in rows) {
          await _db.into(_db.stays).insertOnConflictUpdate(Stay(
                id: (r['id'] as num).toInt(),
                receiptNumber: r['receipt_number'] as String,
                reservationNumber: r['reservation_number'] as String?,
                generatedAt: _parseDate(r['generated_at']) ?? Horloge.maintenant(),
                checkinAt: _parseDate(r['checkin_at']) ?? Horloge.maintenant(),
                checkoutAt: _parseDate(r['checkout_at']) ?? Horloge.maintenant(),
                guestFullName: r['guest_full_name'] as String,
                guestNationality: r['guest_nationality'] as String?,
                guestPhone: r['guest_phone'] as String?,
                guestEmail: r['guest_email'] as String?,
                payerName: r['payer_name'] as String?,
                payerTaxId: r['payer_tax_id'] as String?,
                payerAddress: r['payer_address'] as String?,
                payerContact: r['payer_contact'] as String?,
                subtotalCents: _entier(r['subtotal_cents']),
                remiseCents: _entier(r['remise_cents']),
                remiseKind: _entier(r['remise_kind']),
                remiseValue: _entier(r['remise_value']),
                remiseBase: _entier(r['remise_base']),
                remiseReason: r['remise_reason'] as String?,
                acompteFcCents: _entier(r['acompte_fc_cents']),
                acompteUsdCents: _entier(r['acompte_usd_cents']),
                paymentMode: _entier(r['payment_mode']),
                stayGroup: r['stay_group'] as String?,
                serverLogin: r['server_login'] as String?,
                note: r['note'] as String?,
                extrasJson: (r['extras_json'] as String?) ?? '[]',
                clientVisitsAtCheckout:
                    _entier(r['client_visits_at_checkout']),
                // Le taux figé du séjour. Absent côté miroir sur les
                // séjours d'avant la bascule : 0 signifie « retombe sur
                // le taux courant », et l'écran le dit.
                fcPerUsdCents: _entier(r['fc_per_usd_cents']),
              ));
        }
        for (final l in lignes) {
          await _db.into(_db.stayRooms).insertOnConflictUpdate(StayRoom(
                id: (l['id'] as num).toInt(),
                stayId: (l['stay_id'] as num).toInt(),
                roomNumber: l['room_number'] as String,
                roomType: l['room_type'] as String,
                checkinAt: _parseDate(l['checkin_at']) ?? Horloge.maintenant(),
                checkoutAt: _parseDate(l['checkout_at']) ?? Horloge.maintenant(),
                pricePerNightCents: _entier(l['price_per_night_cents']),
                priceUsdCents: _entier(l['price_usd_cents']),
                listPriceCents: (l['list_price_cents'] as num?)?.toInt(),
                listUsdCents: (l['list_usd_cents'] as num?)?.toInt(),
                nights: _entier(l['nights'], defaut: 1),
              ));
        }
      });
      return rows.length;
    } catch (_) {
      // Best-effort : un historique incomplet vaut mieux qu'un écran en
      // erreur. La prochaine passe rattrapera.
      return 0;
    }
  }

  static int _entier(Object? v, {int defaut = 0}) =>
      v is num ? v.toInt() : defaut;

  /// Récupère les comptes du miroir et fusionne dans local (merge par
  /// login — le passwordHash local est préservé). Un nouveau compte
  /// arrive avec un hash temporaire jetable ; l'utilisateur devra faire
  /// un reset mot de passe au prochain login.
  /// Ancien pull des comptes depuis `mirror_users`. Ne fait plus rien :
  /// le rafraîchissement passe par `UsersRepo.syncFromCloud()`, qui lit
  /// `app_users_public` (vue sans hash) et remonte les erreurs au lieu
  /// de les avaler.
  @Deprecated('Utiliser UsersRepo.syncFromCloud().')
  static Future<int> pullUsersIntoLocal() async => 0;

  // ─── Clients (fidélité) ───────────────────────────────────────────

  static Future<void> pushClientById(int id) async {
    final c = _c;
    if (c == null) return;
    try {
      final row = await (_db.select(_db.clients)..where((x) => x.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return;
      await c.from('mirror_clients').upsert(_clientJson(row), onConflict: 'id');
    } catch (_) {}
  }

  static Future<void> deleteClientById(int id) async {
    final c = _c;
    if (c == null) return;
    try {
      await c.from('mirror_clients').delete().eq('id', id);
    } catch (_) {}
  }

  /// Pull clients depuis le miroir : merge par téléphone si présent,
  /// sinon par nom (case-insensitive). On garde la valeur MAX pour
  /// visits_count / total_spent (pour éviter les régressions dues au
  /// timing entre postes).
  /// Catalogue et stock : du miroir vers le poste, sans rien écraser.
  ///
  /// C'était le trou qui obligeait à cliquer sur « Récupérer depuis les
  /// données miroir » — le bouton qui RASE la base locale. Un article
  /// créé sur un autre poste n'arrivait par aucun autre chemin.
  ///
  /// Trois précautions, toutes délibérées :
  ///   * on rapproche par NOM, parce que les ids sont propres à chaque
  ///     poste tant que la bascule UUID n'est pas faite ;
  ///   * on ne crée jamais un article déjà présent ;
  ///   * **le stock local n'est jamais écrasé.** Une quantité est un
  ///     fait physique constaté ici ; le miroir peut être en retard de
  ///     plusieurs ventes. Écraser reviendrait à effacer des sorties de
  ///     frigo réelles.
  static Future<int> pullArticlesIntoLocal() async {
    final c = _c;
    if (c == null) return 0;
    try {
      final remote = await c
          .from('mirror_articles')
          .select('id, name, price_cents, category, active, image_path, '
              'track_stock, unit, stock_qty, threshold');
      final rows = (remote as List).cast<Map<String, dynamic>>();
      int applied = 0;
      await _db.transaction(() async {
        for (final r in rows) {
          final nom = (r['name'] as String?)?.trim();
          if (nom == null || nom.isEmpty) continue;

          final ex = await (_db.select(_db.articles)
                ..where((a) => a.name.lower().equals(nom.toLowerCase())))
              .getSingleOrNull();

          final prix = ((r['price_cents'] as num?) ?? 0).toInt();
          final cat = DbCategory
              .values[((r['category'] as num?) ?? 0).toInt().clamp(0, 2)];

          if (ex == null) {
            await _db.into(_db.articles).insert(ArticlesCompanion.insert(
                  name: nom,
                  priceCents: prix,
                  category: cat,
                  active: Value((r['active'] as bool?) ?? true),
                  imagePath: Value(r['image_path'] as String?),
                  trackStock: Value((r['track_stock'] as bool?) ?? false),
                  unit: Value((r['unit'] as String?) ?? 'unité'),
                  // Un article qui arrive d'ailleurs démarre à zéro ici :
                  // personne n'a encore compté ces bouteilles sur CE poste.
                  stockQty: const Value(0),
                  threshold: Value(((r['threshold'] as num?) ?? 0).toInt()),
                ));
            applied++;
          } else {
            // Le serveur fait foi sur la quantité — SAUF si ce poste a
            // des mouvements non encore confirmés pour cet article :
            // adopter la valeur serveur effacerait les ventes faites
            // pendant la coupure.
            final enAttente = await (_db.select(_db.stockMoves)
                  ..where((m) => m.articleId.equals(ex.id) & m.sentAt.isNull()))
                .get();
            final qteServeur = (r['stock_qty'] as num?)?.toInt();
            // Fiche produit.
            await (_db.update(_db.articles)..where((a) => a.id.equals(ex.id)))
                .write(ArticlesCompanion(
              priceCents: Value(prix),
              category: Value(cat),
              active: Value((r['active'] as bool?) ?? ex.active),
              imagePath: Value(r['image_path'] as String? ?? ex.imagePath),
              trackStock: Value((r['track_stock'] as bool?) ?? ex.trackStock),
              unit: Value((r['unit'] as String?) ?? ex.unit),
              threshold:
                  Value(((r['threshold'] as num?) ?? ex.threshold).toInt()),
              stockQty: (enAttente.isEmpty && qteServeur != null)
                  ? Value(qteServeur)
                  : const Value.absent(),
            ));
            applied++;
          }
        }
      });
      return applied;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> pullClientsIntoLocal() async {
    final c = _c;
    if (c == null) return 0;
    try {
      final remote = await c.from('mirror_clients').select();
      final rows = (remote as List).cast<Map<String, dynamic>>();
      int applied = 0;
      await _db.transaction(() async {
        for (final r in rows) {
          final phone = r['phone'] as String?;
          final name = r['full_name'] as String;
          Client? ex;
          if (phone != null && phone.isNotEmpty) {
            ex = await (_db.select(_db.clients)
                  ..where((c) => c.phone.equals(phone)))
                .getSingleOrNull();
          }
          ex ??= await (_db.select(_db.clients)
                ..where((c) => c.fullName.lower().equals(name.toLowerCase())))
              .getSingleOrNull();
          final visitsR = ((r['visits_count'] as num?) ?? 0).toInt();
          final spentR = ((r['total_spent_cents'] as num?) ?? 0).toInt();
          if (ex != null) {
            await (_db.update(_db.clients)..where((x) => x.id.equals(ex!.id)))
                .write(ClientsCompanion(
              fullName: Value(name),
              phone: Value(phone),
              email: Value(r['email'] as String?),
              notes: Value(r['notes'] as String?),
              visitsCount:
                  Value(visitsR > ex.visitsCount ? visitsR : ex.visitsCount),
              totalSpentCents: Value(
                  spentR > ex.totalSpentCents ? spentR : ex.totalSpentCents),
              lastSeenAt: Value(_parseDate(r['last_seen_at']) ?? ex.lastSeenAt),
            ));
          } else {
            await _db.into(_db.clients).insert(ClientsCompanion.insert(
                  fullName: name,
                  phone: phone == null || phone.isEmpty
                      ? const Value.absent()
                      : Value(phone),
                  email: r['email'] == null
                      ? const Value.absent()
                      : Value(r['email'] as String?),
                  notes: r['notes'] == null
                      ? const Value.absent()
                      : Value(r['notes'] as String?),
                  visitsCount: Value(visitsR),
                  totalSpentCents: Value(spentR),
                  firstSeenAt:
                      Value(_parseDate(r['first_seen_at']) ?? Horloge.maintenant()),
                  lastSeenAt:
                      Value(_parseDate(r['last_seen_at']) ?? Horloge.maintenant()),
                ));
          }
          applied++;
        }
      });
      return applied;
    } catch (_) {
      return 0;
    }
  }

  // ─── Payeurs (prise en charge) ────────────────────────────────────

  static Future<void> pushPayerById(int id) async {
    final c = _c;
    if (c == null) return;
    try {
      final row = await (_db.select(_db.payers)..where((x) => x.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return;
      await c.from('mirror_payers').upsert(_payerJson(row), onConflict: 'id');
    } catch (_) {}
  }

  static Future<void> deletePayerById(int id) async {
    final c = _c;
    if (c == null) return;
    try {
      await c.from('mirror_payers').delete().eq('id', id);
    } catch (_) {}
  }

  /// Pull payeurs — merge par nom (case-insensitive) puisqu'il n'y a
  /// pas de contrainte unique naturelle plus fine.
  static Future<int> pullPayersIntoLocal() async {
    final c = _c;
    if (c == null) return 0;
    try {
      final remote = await c.from('mirror_payers').select();
      final rows = (remote as List).cast<Map<String, dynamic>>();
      int applied = 0;
      await _db.transaction(() async {
        for (final r in rows) {
          final name = r['name'] as String;
          final type = DbPayerType.values[(r['type'] as num? ?? 1).toInt()];
          final ex = await (_db.select(_db.payers)
                ..where((p) => p.name.lower().equals(name.toLowerCase())))
              .getSingleOrNull();
          if (ex != null) {
            await (_db.update(_db.payers)..where((p) => p.id.equals(ex.id)))
                .write(PayersCompanion(
              type: Value(type),
              taxId: Value(r['tax_id'] as String?),
              address: Value(r['address'] as String?),
              contact: Value(r['contact'] as String?),
              notes: Value(r['notes'] as String?),
            ));
          } else {
            await _db.into(_db.payers).insert(PayersCompanion.insert(
                  name: name,
                  type: Value(type),
                  taxId: r['tax_id'] == null
                      ? const Value.absent()
                      : Value(r['tax_id'] as String?),
                  address: r['address'] == null
                      ? const Value.absent()
                      : Value(r['address'] as String?),
                  contact: r['contact'] == null
                      ? const Value.absent()
                      : Value(r['contact'] as String?),
                  notes: r['notes'] == null
                      ? const Value.absent()
                      : Value(r['notes'] as String?),
                  createdAt:
                      Value(_parseDate(r['created_at']) ?? Horloge.maintenant()),
                ));
          }
          applied++;
        }
      });
      return applied;
    } catch (_) {
      return 0;
    }
  }

  // ─── Suppression d'une vente (propagation Supabase) ────────────────

  static Future<void> deleteSaleById(int saleId) async {
    final c = _c;
    if (c == null) return;
    try {
      await c.from('mirror_sale_lines').delete().eq('sale_id', saleId);
      await c.from('mirror_sales').delete().eq('id', saleId);
    } catch (_) {
      // best-effort
    }
  }

  // ─── Push incrémental d'un produit (création / édition) ──────────────

  static Future<void> pushArticleById(int articleId) async {
    final c = _c;
    if (c == null) return;
    try {
      final art = await (_db.select(_db.articles)
            ..where((a) => a.id.equals(articleId)))
          .getSingleOrNull();
      if (art == null) return;
      await c
          .from('mirror_articles')
          .upsert(_articleJson(art), onConflict: 'id');
    } catch (_) {
      // best-effort
    }
  }

  // ─── Synchronisation complète (bouton manuel / démarrage) ────────────

  static Future<String> syncAll() async {
    final c = _c;
    if (c == null) return 'Cloud non configuré';
    try {
      final articles = await _db.select(_db.articles).get();
      final rooms = await _db.select(_db.rooms).get();
      final users = await _db.select(_db.users).get();

      if (articles.isNotEmpty) {
        await c
            .from('mirror_articles')
            .upsert(articles.map(_articleJson).toList(), onConflict: 'id');
      }
      if (rooms.isNotEmpty) {
        await c
            .from('mirror_rooms')
            .upsert(rooms.map(_roomJson).toList(), onConflict: 'number');
      }
      // Filet : les super admins restent locaux (cf. pushUserById).
      final syncableUsers =
          users.where((u) => u.role != DbUserRole.superAdmin).toList();
      if (syncableUsers.isNotEmpty) {
        await c
            .from('mirror_users')
            .upsert(syncableUsers.map(_userJson).toList(), onConflict: 'login');
      }
      // Les ventes ne sont plus repoussées en bloc ici.
      //
      // Ce renvoi complet coûtait 21 Mo par jour pour 207 ventes, et
      // grandissait avec l'historique. Il aurait fini par dépasser le
      // délai d'attente et par échouer — en silence, comme tout le reste
      // — et c'est précisément là que les vraies pertes auraient
      // commencé, sans que rien ne permette de faire le lien.
      //
      // Désormais chaque vente porte son accusé de réception, et seule
      // la file rattrape ce qui manque.
      final venteEnvoyees = await VentesOutbox.instance.vider();

      // Séjours : jusqu'ici absents du miroir, donc invisibles pour le
      // tableau de bord. On les pousse en bloc pour rattraper l'existant.
      final stays = await _db.select(_db.stays).get();
      if (stays.isNotEmpty) {
        await c
            .from('mirror_stays')
            .upsert(stays.map(_stayJson).toList(), onConflict: 'id');
        final stayRooms = await _db.select(_db.stayRooms).get();
        if (stayRooms.isNotEmpty) {
          await c
              .from('mirror_stay_rooms')
              .upsert(stayRooms.map(_stayRoomJson).toList(), onConflict: 'id');
        }
      }
      final reste = await VentesOutbox.instance.enAttente();
      return reste == 0
          ? 'Synchronisation réussie ($venteEnvoyees vente(s) envoyée(s), '
              '${articles.length} produits)'
          : 'Synchronisation partielle : $venteEnvoyees envoyée(s), '
              '$reste vente(s) encore en attente';
    } catch (e) {
      return 'Échec synchro : $e';
    }
  }

  // ─── Mappage vers JSON (colonnes Supabase) ───────────────────────────

  /// Somme déjà encaissée sur chaque vente à crédit citée.
  ///
  /// Une requête groupée, pas une par vente : `syncAll` pousse des
  /// centaines de lignes et n'a pas à faire des centaines d'allers-
  /// retours SQLite pour ça.
  static Future<Map<int, int>> _dejaPayeParVente(List<int> saleIds) async {
    if (saleIds.isEmpty) return const {};
    final d = _db.debtPayments;
    final somme = d.amountCents.sum();
    final q = _db.selectOnly(d)
      ..addColumns([d.saleId, somme])
      ..where(d.saleId.isIn(saleIds))
      ..groupBy([d.saleId]);
    final rows = await q.get();
    return {
      for (final r in rows) r.read(d.saleId)!: r.read(somme) ?? 0,
    };
  }

  /// [dejaPaye] : ce qui a déjà été encaissé sur cette vente.
  ///
  /// Indispensable depuis les règlements partiels : sans lui, le
  /// tableau de bord compterait le ticket ENTIER comme à recouvrer,
  /// alors que le client a peut-être versé les trois quarts. L'encours
  /// annoncé à Pamela serait faux, toujours dans le même sens — trop
  /// gros.
  static Map<String, dynamic> _saleJson(Sale s, {int dejaPaye = 0}) => {
        'paid_cents': dejaPaye,
        'id': s.id,
        'sold_at': isoServeur(s.soldAt),
        'server_user_id': s.serverUserId,
        'payment': s.payment.index,
        'location': s.location.index,
        'customer_name': s.customerName,
        'room_number': s.roomNumber,
        'on_credit': s.onCredit,
        'settled_at': isoServeurOuNull(s.settledAt),
        'note': s.note,
      };

  static Map<String, dynamic> _lineJson(SaleLine l) => {
        'id': l.id,
        'sale_id': l.saleId,
        'article_id': l.articleId,
        'article_name': l.articleName,
        'qty': l.qty,
        'unit_price_cents': l.unitPriceCents,
      };

  // Note : `price_cents` / `unit_price_cents` / `price_per_night_cents`
  // désignent désormais un montant FC entier (pas des cents USD).
  // Les noms de colonnes Supabase sont conservés pour éviter une migration.
  /// Fiche produit, **sans la quantité**.
  ///
  /// Depuis le passage aux deltas, `mirror_articles.stock_qty` est
  /// calculé par le serveur seul (`bs_adjust_stock`). L'envoyer d'ici
  /// écraserait ce calcul.
  ///
  /// Ce n'est pas une précaution théorique : le 21 septembre, un
  /// diagnostic a retiré 1 au stock via la RPC, l'application a repoussé
  /// l'ancienne quantité absolue dans les quinze secondes, et le
  /// mouvement a été effacé. Le stock avait gagné une unité au lieu d'en
  /// perdre une.
  /// Champs de la fiche produit envoyés au miroir.
  ///
  /// Exposé pour qu'un test puisse vérifier que `stock_qty` n'y est PAS :
  /// c'est le retour de ce champ qui a effacé un mouvement de stock en
  /// production le 21 septembre.
  static Set<String> get champsFicheArticle =>
      _articleJson(_articleTemoin).keys.toSet();

  static final _articleTemoin = Article(
    id: 0,
    name: '',
    priceCents: 0,
    category: DbCategory.boissons,
    active: true,
    imagePath: null,
    trackStock: true,
    unit: '',
    stockQty: 0,
    threshold: 0,
  );

  static Map<String, dynamic> _articleJson(Article a) => {
        'id': a.id,
        'name': a.name,
        'price_cents': a.priceCents,
        'category': a.category.index,
        'active': a.active,
        'track_stock': a.trackStock,
        'unit': a.unit,
        'threshold': a.threshold,
        'image_path': a.imagePath,
      };

  static Map<String, dynamic> _roomJson(Room r) => {
        'number': r.number,
        'type': r.type,
        // Le tarif dans les deux devises : le dollar est la source, le
        // franc la conversion. Le tableau de bord de Pamela lit l'un ou
        // l'autre selon ce qu'elle regarde.
        'price_usd_cents': r.priceUsdCents,
        'price_per_night_cents': r.pricePerNightCents,
        'status': r.status.index,
        'current_guest': r.currentGuest,
        'checkout_date': isoServeurOuNull(r.checkoutDate),
        'checkin_note': r.checkinNote,
        'checkin_at': isoServeurOuNull(r.checkinAt),
        'stay_group': r.stayGroup,
        'payer_id': r.payerId,
        'image_path': r.imagePath,
        'negotiated_price_cents': r.negotiatedPriceCents,
      };

  static Map<String, dynamic> _clientJson(Client c) => {
        'id': c.id,
        'full_name': c.fullName,
        'phone': c.phone,
        'email': c.email,
        'notes': c.notes,
        'first_seen_at': isoServeur(c.firstSeenAt),
        'last_seen_at': isoServeur(c.lastSeenAt),
        'visits_count': c.visitsCount,
        'total_spent_cents': c.totalSpentCents,
      };

  static Map<String, dynamic> _reservationJson(Reservation r) => {
        'id': r.id,
        'reservation_number': r.reservationNumber,
        'created_at': isoServeur(r.createdAt),
        'checkin_date': isoServeur(r.checkinDate),
        'checkout_date': isoServeur(r.checkoutDate),
        'guest_full_name': r.guestFullName,
        'guest_phone': r.guestPhone,
        'guest_email': r.guestEmail,
        'payer_id': r.payerId,
        'status': r.status.index,
        'deposit_cents': r.depositCents,
        'note': r.note,
        'created_by_login': r.createdByLogin,
        'cancelled_at': isoServeurOuNull(r.cancelledAt),
        'cancel_reason': r.cancelReason,
        'stay_id': r.stayId,
      };

  static Map<String, dynamic> _reservationRoomJson(ReservationRoom rr) => {
        'id': rr.id,
        'reservation_id': rr.reservationId,
        'room_number': rr.roomNumber,
        'price_per_night_cents': rr.pricePerNightCents,
      };

  static Map<String, dynamic> _stayJson(Stay s) => {
        'id': s.id,
        'receipt_number': s.receiptNumber,
        'reservation_number': s.reservationNumber,
        'generated_at': isoServeur(s.generatedAt),
        'checkin_at': isoServeur(s.checkinAt),
        'checkout_at': isoServeur(s.checkoutAt),
        'guest_full_name': s.guestFullName,
        'guest_nationality': s.guestNationality,
        'guest_phone': s.guestPhone,
        'guest_email': s.guestEmail,
        'payer_name': s.payerName,
        'payer_tax_id': s.payerTaxId,
        'payer_address': s.payerAddress,
        'payer_contact': s.payerContact,
        'subtotal_cents': s.subtotalCents,
        'remise_cents': s.remiseCents,
        'remise_kind': s.remiseKind,
        'remise_value': s.remiseValue,
        'remise_base': s.remiseBase,
        'remise_reason': s.remiseReason,
        'acompte_fc_cents': s.acompteFcCents,
        'acompte_usd_cents': s.acompteUsdCents,
        'fc_per_usd_cents': s.fcPerUsdCents,
        'payment_mode': s.paymentMode,
        'stay_group': s.stayGroup,
        'server_login': s.serverLogin,
        'note': s.note,
        'extras_json': s.extrasJson,
        'client_visits_at_checkout': s.clientVisitsAtCheckout,
      };

  static Map<String, dynamic> _stayRoomJson(StayRoom r) => {
        'id': r.id,
        'stay_id': r.stayId,
        'room_number': r.roomNumber,
        'room_type': r.roomType,
        'checkin_at': isoServeur(r.checkinAt),
        'checkout_at': isoServeur(r.checkoutAt),
        'price_per_night_cents': r.pricePerNightCents,
        'price_usd_cents': r.priceUsdCents,
        'list_price_cents': r.listPriceCents,
        'list_usd_cents': r.listUsdCents,
        'nights': r.nights,
      };

  static Map<String, dynamic> _payerJson(Payer p) => {
        'id': p.id,
        'name': p.name,
        'type': p.type.index,
        'tax_id': p.taxId,
        'address': p.address,
        'contact': p.contact,
        'notes': p.notes,
        'created_at': isoServeur(p.createdAt),
      };

  // Pas de mot de passe dans le miroir (sécurité).
  static Map<String, dynamic> _userJson(User u) => {
        'id': u.id,
        'full_name': u.fullName,
        'login': u.login,
        'role': u.role.index,
        'active': u.active,
        'created_at': isoServeur(u.createdAt),
        'last_login': isoServeurOuNull(u.lastLogin),
      };
}
