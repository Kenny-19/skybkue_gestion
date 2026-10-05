import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../core/auth.dart';
import '../core/cloud_config.dart';
import '../core/temps.dart';
import '../data/database.dart';
import '../data/schema.dart';
import '../core/horloge.dart';
import '../core/identite.dart';
import 'heartbeat_service.dart';
import 'supabase_pages.dart';
import 'ventes_outbox.dart';

/// Miroir des données locales vers Supabase (sens unique : local = maître).
///
/// Permet de consulter les ventes/produits dans le dashboard Supabase même si
/// l'app locale plante. Chaque écriture importante est repoussée vers des
/// tables `mirror_*`. Hors ligne → ignoré (les données restent en local, une
/// synchro complète les rattrapera).
/// Bilan de [MirrorService.verifierVentesDuPoste].
class VerificationVentes {
  /// Ventes de ce poste que le serveur n'a pas. Non renvoyées d'office.
  final List<Sale> absentes;

  /// Lignes que le serveur avait perdues, renvoyées.
  final int lignesRestaurees;

  /// Ventes dont l'heure était décalée sur le serveur, corrigées.
  final int heuresCorrigees;

  final int ventesVerifiees;

  const VerificationVentes({
    required this.absentes,
    required this.lignesRestaurees,
    required this.heuresCorrigees,
    required this.ventesVerifiees,
  });
}

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

    // Le serveur reconnaît la vente par son uid, plus par son numéro :
    // la vente n° 345 de deux postes, ce sont deux ventes.
    final uid = sale.uid ?? uidVenteHerite(sale.id, sale.soldAt);
    if (sale.uid == null) {
      await (_db.update(_db.sales)..where((s) => s.id.equals(saleId)))
          .write(SalesCompanion(uid: Value(uid)));
    }
    final deja = await _dejaPayeParVente([saleId]);
    final corps = _saleJson(sale, uid, dejaPaye: deja[saleId] ?? 0);

    // 1. Création seulement (« on conflict do nothing ») : le numéro du
    //    ticket et le poste d'origine. Une copie de la vente sur un autre
    //    poste, renvoyée plus tard, ne doit jamais les écraser.
    await c.from('mirror_sales').upsert({
      ...corps,
      'numero_local': sale.id,
      'poste': HeartbeatService.nomDuPoste,
    }, onConflict: 'uid', ignoreDuplicates: true);
    // 2. Ce qui peut changer (règlement d'une dette) ; et le numéro que le
    //    serveur a donné à la vente, auquel les lignes se rattachent.
    final rangee = await c
        .from('mirror_sales')
        .upsert(corps, onConflict: 'uid')
        .select('id')
        .single();
    final idServeur = (rangee['id'] as num).toInt();

    if (lines.isNotEmpty) {
      await c.from('mirror_sale_lines').upsert(
          [for (final l in lines) _lineJson(l, uid, idServeur)],
          onConflict: 'uid');
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
      await _pousserSejours([stay]);
    } catch (_) {
      // best-effort
    }
  }

  /// Envoie des séjours FACTURÉS et leurs chambres, par uid. Lève en cas
  /// d'échec.
  ///
  /// Seuls les séjours facturés partent : un séjour en cours n'a pas
  /// encore de montant, et un séjour libéré sans facture n'en aura pas —
  /// le tableau de bord compte des recettes.
  ///
  /// Même schéma que les ventes : création seule pour le numéro local et
  /// le poste, puis mise à jour du reste ; le serveur numérote, et les
  /// chambres se rattachent à son numéro.
  static Future<void> _pousserSejours(List<Stay> sejours) async {
    final c = _c;
    if (c == null) return;
    final factures =
        sejours.where((s) => s.statut == DbStayStatus.facture).toList();
    if (factures.isEmpty) return;
    final poste = HeartbeatService.nomDuPoste;
    for (var i = 0; i < factures.length; i += 200) {
      final lot = factures.sublist(i, (i + 200).clamp(0, factures.length));
      final uidParId = {
        for (final s in lot) s.id: s.uid ?? uidSejourHerite(s.id, s.checkoutAt)
      };
      final corps = [for (final s in lot) _stayJson(s, uidParId[s.id]!)];
      await c.from('mirror_stays').upsert([
        for (var k = 0; k < lot.length; k++)
          {...corps[k], 'numero_local': lot[k].id, 'poste': poste},
      ], onConflict: 'uid', ignoreDuplicates: true);
      final rangees = await c
          .from('mirror_stays')
          .upsert(corps, onConflict: 'uid')
          .select('id, uid');
      final idServeurParUid = {
        for (final r in rangees) r['uid'] as String: (r['id'] as num).toInt()
      };
      final chambres = await (_db.select(_db.stayRooms)
            ..where((r) => r.stayId.isIn(lot.map((s) => s.id).toList())))
          .get();
      if (chambres.isEmpty) continue;
      await c.from('mirror_stay_rooms').upsert([
        for (final r in chambres)
          _stayRoomJson(
              r, uidParId[r.stayId]!, idServeurParUid[uidParId[r.stayId]]!),
      ], onConflict: 'uid');
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
      // 0. Refus tant qu'une vente du poste n'est pas sur le serveur.
      //
      // La restauration efface TOUTES les ventes locales. Une vente
      // encaissée pendant une coupure n'existe qu'ici : l'effacer, c'est
      // la perdre pour de bon, recette comprise. On vide la file d'abord ;
      // si le réseau ne suit pas, on s'arrête et on dit pourquoi.
      await VentesOutbox.instance.vider(lot: 1000);
      final enAttente = await VentesOutbox.instance.enAttente();
      if (enAttente > 0) {
        return MirrorRestoreResult(
            ok: false,
            message: '$enAttente vente(s) de ce poste ne sont pas encore sur '
                'le serveur. La restauration les effacerait. Rétablis la '
                'connexion et attends qu\'elles partent, puis réessaie.');
      }

      // 1. Fetch de toutes les tables miroir en parallèle, EN ENTIER.
      //
      // Sans pagination, cette restauration effaçait toutes les ventes
      // locales puis n'en recopiait que les 1000 premières lignes :
      // au-delà, l'historique disparaissait pour de bon.
      final results = await Future.wait([
        toutesLesPages(() => c.from('mirror_articles').select().order('id')),
        toutesLesPages(() => c.from('mirror_rooms').select().order('number')),
        toutesLesPages(() => c.from('mirror_sales').select().order('id')),
        toutesLesPages(() => c.from('mirror_sale_lines').select().order('id')),
        toutesLesPages(() => c.from('mirror_users').select().order('id')),
      ]);
      final articles = results[0];
      final rooms = results[1];
      final sales = results[2];
      final lines = results[3];
      final users = results[4];

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
                    createdAt: Value(
                        _parseDate(u['created_at']) ?? Horloge.maintenant()),
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
        //
        // Le numéro du serveur est unique sur le serveur : il peut servir
        // de numéro local dans une base vidée. L'uid, lui, est repris tel
        // quel — c'est ce qui permet au poste de retrouver ses ventes.
        final uidParVente = <int, String>{};
        for (final s in sales) {
          final mirrorServerId = (s['server_user_id'] as num?)?.toInt();
          final localServerId =
              mirrorServerId == null ? null : userIdMap[mirrorServerId];
          final uid = _uidDeVente(s);
          uidParVente[(s['id'] as num).toInt()] = uid;
          await _db.into(_db.sales).insert(
                SalesCompanion.insert(
                  id: Value((s['id'] as num).toInt()),
                  uid: Value(uid),
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
                  // Elle vient du serveur : déjà en lieu sûr. Sans ça,
                  // toute la base restaurée repartait dans la file des
                  // ventes en attente.
                  syncedAt: Value(Horloge.maintenant()),
                ),
              );
        }

        // Lignes de vente — sale_id et article_id ont leurs ids miroir
        // préservés ci-dessus, les FK restent valides.
        for (final l in lines) {
          final venteServeur = (l['sale_id'] as num).toInt();
          await _db.into(_db.saleLines).insert(
                SaleLinesCompanion.insert(
                  saleId: venteServeur,
                  articleId: Value((l['article_id'] as num?)?.toInt()),
                  articleName: l['article_name'] as String,
                  qty: (l['qty'] as num).toInt(),
                  unitPriceCents: (l['unit_price_cents'] as num).toInt(),
                  uid: Value(_uidDeLigne(l, uidParVente[venteServeur])),
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

  /// L'uid d'une vente lue sur le serveur. Avant le script
  /// 2026_10_identite_ventes.sql, la colonne n'existe pas : on le déduit
  /// alors comme le serveur le fera.
  static String _uidDeVente(Map<String, dynamic> s) =>
      (s['uid'] as String?) ??
      uidVenteHerite((s['id'] as num).toInt(),
          _parseDate(s['sold_at']) ?? DateTime.fromMillisecondsSinceEpoch(0));

  /// L'uid d'un séjour lu sur le serveur (déduit, avant le script
  /// 2026_10_identite_sejours.sql).
  static String _uidDeSejour(Map<String, dynamic> s) =>
      (s['uid'] as String?) ??
      uidSejourHerite(
          (s['id'] as num).toInt(),
          _parseDate(s['checkout_at']) ??
              DateTime.fromMillisecondsSinceEpoch(0));

  static String _uidDeLigne(Map<String, dynamic> l, String? uidVente) =>
      (l['uid'] as String?) ??
      uidLigneHerite(uidVente ?? nouvelUid(), (l['id'] as num).toInt());

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
      // Paginé : cette fonction SUPPRIME les chambres absentes de la
      // réponse. Une réponse tronquée y deviendrait une suppression.
      final rows = await toutesLesPages(
          () => c.from('mirror_rooms').select().order('number'));
      // Même logique pour une réponse vide : c'est un serveur filtré ou
      // à moitié en place, pas un hôtel sans chambres.
      if (rows.isEmpty) return 0;
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
      // 500 séjours peuvent porter plus de 1000 chambres : paginé.
      final lignes = await toutesLesPagesParIds(
          ids,
          (paquet) => c
              .from('mirror_stay_rooms')
              .select()
              .inFilter('stay_id', paquet)
              .order('id'));

      // Reconnus par leur UID (v27). Avant, le séjour était écrit sous le
      // numéro du serveur : il pouvait écraser un séjour local de même
      // numéro — et depuis que les séjours existent dès l'arrivée, ce
      // pouvait être un client encore dans sa chambre.
      final dejaLa = {
        for (final s in await _db.select(_db.stays).get())
          if (s.uid != null) s.uid!,
      };
      final uidParServeur = {
        for (final r in rows) (r['id'] as num).toInt(): _uidDeSejour(r)
      };
      final localParServeur = <int, int>{};
      var ajoutes = 0;

      await _db.transaction(() async {
        for (final r in rows) {
          final idServeur = (r['id'] as num).toInt();
          final uid = uidParServeur[idServeur]!;
          if (dejaLa.contains(uid)) continue;
          // Pas d'`id` : la copie prend un numéro de ce poste.
          localParServeur[idServeur] = await _db
              .into(_db.stays)
              .insert(StaysCompanion.insert(
                uid: Value(uid),
                statut: const Value(DbStayStatus.facture),
                receiptNumber: r['receipt_number'] as String,
                reservationNumber: Value(r['reservation_number'] as String?),
                generatedAt: Value(
                    _parseDate(r['generated_at']) ?? Horloge.maintenant()),
                checkinAt: _parseDate(r['checkin_at']) ?? Horloge.maintenant(),
                checkoutAt:
                    _parseDate(r['checkout_at']) ?? Horloge.maintenant(),
                guestFullName: r['guest_full_name'] as String,
                guestNationality: Value(r['guest_nationality'] as String?),
                guestPhone: Value(r['guest_phone'] as String?),
                guestEmail: Value(r['guest_email'] as String?),
                payerName: Value(r['payer_name'] as String?),
                payerTaxId: Value(r['payer_tax_id'] as String?),
                payerAddress: Value(r['payer_address'] as String?),
                payerContact: Value(r['payer_contact'] as String?),
                subtotalCents: _entier(r['subtotal_cents']),
                remiseCents: Value(_entier(r['remise_cents'])),
                remiseKind: Value(_entier(r['remise_kind'])),
                remiseValue: Value(_entier(r['remise_value'])),
                remiseBase: Value(_entier(r['remise_base'])),
                remiseReason: Value(r['remise_reason'] as String?),
                acompteFcCents: Value(_entier(r['acompte_fc_cents'])),
                acompteUsdCents: Value(_entier(r['acompte_usd_cents'])),
                paymentMode: Value(_entier(r['payment_mode'])),
                stayGroup: Value(r['stay_group'] as String?),
                serverLogin: Value(r['server_login'] as String?),
                note: Value(r['note'] as String?),
                extrasJson: Value((r['extras_json'] as String?) ?? '[]'),
                clientVisitsAtCheckout:
                    Value(_entier(r['client_visits_at_checkout'])),
                // Le taux figé du séjour. Absent côté miroir sur les
                // séjours d'avant la bascule : 0 signifie « retombe
                // sur le taux courant », et l'écran le dit.
                fcPerUsdCents: Value(_entier(r['fc_per_usd_cents'])),
              ));
          ajoutes++;
        }
        for (final l in lignes) {
          final idServeur = (l['stay_id'] as num).toInt();
          final local = localParServeur[idServeur];
          if (local == null) continue; // séjour déjà présent : intouché
          await _db.into(_db.stayRooms).insert(
                StayRoomsCompanion.insert(
                  uid: Value((l['uid'] as String?) ??
                      uidLigneHerite(
                          uidParServeur[idServeur]!, (l['id'] as num).toInt())),
                  stayId: local,
                  roomNumber: l['room_number'] as String,
                  roomType: l['room_type'] as String,
                  checkinAt:
                      _parseDate(l['checkin_at']) ?? Horloge.maintenant(),
                  checkoutAt:
                      _parseDate(l['checkout_at']) ?? Horloge.maintenant(),
                  pricePerNightCents: _entier(l['price_per_night_cents']),
                  priceUsdCents: Value(_entier(l['price_usd_cents'])),
                  listPriceCents:
                      Value((l['list_price_cents'] as num?)?.toInt()),
                  listUsdCents: Value((l['list_usd_cents'] as num?)?.toInt()),
                  nights: _entier(l['nights'], defaut: 1),
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
      });
      return ajoutes;
    } catch (_) {
      // Best-effort : un historique incomplet vaut mieux qu'un écran en
      // erreur. La prochaine passe rattrapera.
      return 0;
    }
  }

  static int _entier(Object? v, {int defaut = 0}) =>
      v is num ? v.toInt() : defaut;

  /// Ventes du miroir absentes de ce poste : on les AJOUTE, rien d'autre.
  ///
  /// C'est la moitié sûre de la récupération d'urgence. Celle-ci efface
  /// toutes les ventes locales avant de recopier le miroir ; ici :
  ///   * une vente est reconnue par son UID, jamais par son numéro : la
  ///     vente n° 345 d'un autre poste n'est pas celle de ce poste ;
  ///   * une vente déjà présente n'est jamais modifiée ; si elle est
  ///     restée sans aucune ligne (factures vides de septembre), ses
  ///     lignes sont complétées ;
  ///   * la copie reçoit un numéro de CE poste, et garde l'uid d'origine ;
  ///   * rien n'est supprimé, le stock n'est pas bougé ;
  ///   * la vente ajoutée est marquée « déjà sur le serveur » : elle ne
  ///     repart pas dans la file, et ne peut donc pas écraser au serveur
  ///     le `paid_cents` qu'un autre poste y a mis.
  ///
  /// Pas appelée par la synchro des 15 secondes : relire toute la table
  /// des ventes à chaque tour coûterait ce que la file a justement
  /// supprimé. Seulement sur le bouton « Récupérer maintenant ».
  static Future<int> pullSalesIntoLocal() async {
    final c = _c;
    if (c == null) return 0;

    final distantes =
        await toutesLesPages(() => c.from('mirror_sales').select().order('id'));
    if (distantes.isEmpty) return 0;

    // Ventes locales par uid, et celles qui n'ont AUCUNE ligne.
    final idLocalParUid = <String, int>{
      for (final v in await _db.select(_db.sales).get())
        if (v.uid != null) v.uid!: v.id,
    };
    final idsAvecLignes = (await (_db.selectOnly(_db.saleLines, distinct: true)
              ..addColumns([_db.saleLines.saleId]))
            .get())
        .map((r) => r.read(_db.saleLines.saleId)!)
        .toSet();

    final manquantes = <Map<String, dynamic>>[];
    // numéro serveur → numéro local, pour rattacher les lignes.
    final localParServeur = <int, int>{};
    for (final s in distantes) {
      final idServeur = (s['id'] as num).toInt();
      final idLocal = idLocalParUid[_uidDeVente(s)];
      if (idLocal == null) {
        manquantes.add(s);
      } else if (!idsAvecLignes.contains(idLocal)) {
        localParServeur[idServeur] = idLocal; // vente à compléter
      }
    }
    final aCompleter = localParServeur.length;
    if (manquantes.isEmpty && aCompleter == 0) return 0;

    final idsServeur = [
      ...manquantes.map((s) => (s['id'] as num).toInt()),
      ...localParServeur.keys,
    ];
    final lignes = await toutesLesPagesParIds(
        idsServeur,
        (paquet) => c
            .from('mirror_sale_lines')
            .select()
            .inFilter('sale_id', paquet)
            .order('id'));

    // Le serveur de la vente : id miroir → login → compte local. Au mieux
    // seulement — une vente sans serveur reste une vente.
    final loginParIdMiroir = <int, String>{};
    try {
      final res = await toutesLesPages(
          () => c.from('mirror_users').select('id, login').order('id'));
      for (final u in res) {
        loginParIdMiroir[(u['id'] as num).toInt()] =
            (u['login'] as String).toLowerCase();
      }
    } catch (_) {}
    final comptes = await _db.select(_db.users).get();
    final idLocalParLogin = {
      for (final u in comptes) u.login.toLowerCase(): u.id
    };

    // L'article de la ligne : rapproché par NOM, comme le catalogue. Le
    // nom figé sur la ligne suffit à la facture si l'article n'existe pas.
    final articles = await _db.select(_db.articles).get();
    final articleParNom = {
      for (final a in articles) a.name.trim().toLowerCase(): a.id
    };

    final uidParServeur = {
      for (final s in distantes) (s['id'] as num).toInt(): _uidDeVente(s)
    };

    await _db.transaction(() async {
      for (final s in manquantes) {
        final idServeurMiroir = (s['server_user_id'] as num?)?.toInt();
        final login =
            idServeurMiroir == null ? null : loginParIdMiroir[idServeurMiroir];
        // Pas d'`id` : la copie prend un numéro de ce poste. Celui du
        // serveur pourrait déjà désigner une vente locale.
        final idLocal = await _db.into(_db.sales).insert(
              SalesCompanion.insert(
                uid: Value(_uidDeVente(s)),
                soldAt: _parseDate(s['sold_at']) ?? Horloge.maintenant(),
                serverUserId:
                    Value(login == null ? null : idLocalParLogin[login]),
                payment: DbPayment.values[(s['payment'] as num).toInt()],
                location:
                    Value(DbLocation.values[(s['location'] as num).toInt()]),
                customerName: Value(s['customer_name'] as String?),
                roomNumber: Value(s['room_number'] as String?),
                onCredit: Value((s['on_credit'] as bool?) ?? false),
                settledAt: Value(_parseDate(s['settled_at'])),
                note: Value(s['note'] as String?),
                syncedAt: Value(Horloge.maintenant()),
              ),
            );
        localParServeur[(s['id'] as num).toInt()] = idLocal;
      }
      for (final l in lignes) {
        final venteServeur = (l['sale_id'] as num).toInt();
        final venteLocale = localParServeur[venteServeur];
        if (venteLocale == null) continue;
        final nom = l['article_name'] as String;
        await _db.into(_db.saleLines).insert(
              SaleLinesCompanion.insert(
                saleId: venteLocale,
                articleId: Value(articleParNom[nom.trim().toLowerCase()]),
                articleName: nom,
                qty: (l['qty'] as num).toInt(),
                unitPriceCents: (l['unit_price_cents'] as num).toInt(),
                uid: Value(_uidDeLigne(l, uidParServeur[venteServeur])),
              ),
              // L'uid est unique : une ligne déjà là n'est pas doublée.
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
    return manquantes.length + aCompleter;
  }

  /// Compare les ventes de ce poste à celles du serveur, répare ce qui se
  /// répare sans risque, et liste le reste.
  ///
  /// Pourquoi ce passage : tant que le serveur rangeait les ventes par
  /// numéro local, deux postes écrasaient mutuellement leurs ventes et
  /// leurs lignes. Avec l'identité (uid), on peut enfin voir lesquelles
  /// manquent.
  ///
  /// Réparé automatiquement :
  ///   * les LIGNES absentes d'une vente présente sur le serveur. Une ligne
  ///     ne se modifie jamais après l'encaissement : si le poste en a une
  ///     que le serveur n'a pas, c'est le serveur qui l'a perdue ;
  ///   * l'HEURE d'une vente envoyée avec le décalage de fuseau de
  ///     septembre (même numéro, même lieu, même paiement, heure décalée
  ///     d'un nombre exact d'heures) : le serveur reprend l'heure et l'uid
  ///     du poste.
  ///
  /// Seulement listé : les ventes ABSENTES du serveur. Ce poste peut
  /// garder la copie d'une vente qu'un gérant a supprimée ailleurs ; la
  /// renvoyer d'office la ferait revenir. C'est au super admin de choisir
  /// (cf. [renvoyerVentes]).
  static Future<VerificationVentes> verifierVentesDuPoste() async {
    final c = _c;
    if (c == null) {
      throw StateError('Cloud non configuré');
    }
    final serveur = await toutesLesPages(() => c
        .from('mirror_sales')
        .select('id, uid, sold_at, location, payment, numero_local')
        .order('id'));
    final idServeurParUid = <String, int>{
      for (final s in serveur) _uidDeVente(s): (s['id'] as num).toInt()
    };
    final parNumero = <int, List<Map<String, dynamic>>>{};
    for (final s in serveur) {
      final n = ((s['numero_local'] ?? s['id']) as num).toInt();
      (parNumero[n] ??= []).add(s);
    }

    // Seulement les ventes déjà confirmées : celles en attente sont le
    // travail de la file d'envoi.
    final locales = await (_db.select(_db.sales)
          ..where((s) => s.syncedAt.isNotNull()))
        .get();

    final absentes = <Sale>[];
    final presentes = <int, int>{}; // numéro local → numéro serveur
    var heures = 0;
    for (final v in locales) {
      final uid = v.uid ?? uidVenteHerite(v.id, v.soldAt);
      final trouvee = idServeurParUid[uid];
      if (trouvee != null) {
        presentes[v.id] = trouvee;
        continue;
      }
      final decalee = _venteDecalee(v, parNumero[v.id] ?? const []);
      if (decalee != null) {
        await c.from('mirror_sales').update({
          'uid': uid,
          'sold_at': isoServeur(v.soldAt),
        }).eq('id', decalee);
        presentes[v.id] = decalee;
        heures++;
        continue;
      }
      absentes.add(v);
    }

    // Lignes : ce que le poste a et que le serveur n'a plus.
    final lignesServeur = await toutesLesPages(() => c
        .from('mirror_sale_lines')
        .select('uid, sale_id, article_name, qty, unit_price_cents')
        .order('id'));
    final uidsLignesServeur = {
      for (final l in lignesServeur) l['uid'] as String?
    };
    final contenuServeur = <int, List<String>>{};
    for (final l in lignesServeur) {
      (contenuServeur[(l['sale_id'] as num).toInt()] ??= []).add(
          _signatureLigne(
              l['article_name'] as String,
              (l['qty'] as num).toInt(),
              (l['unit_price_cents'] as num).toInt()));
    }
    var lignesRendues = 0;
    for (final MapEntry(key: idLocal, value: idServeur) in presentes.entries) {
      final lignesLocales = await (_db.select(_db.saleLines)
            ..where((l) => l.saleId.equals(idLocal)))
          .get();
      final restant = List<String>.of(contenuServeur[idServeur] ?? const []);
      for (final l in lignesLocales) {
        if (restant
            .remove(_signatureLigne(l.articleName, l.qty, l.unitPriceCents))) {
          continue;
        }
        // Absente du serveur. Si son uid y est déjà, rattaché à une autre
        // vente (ancien écrasement), on lui en donne un neuf : renvoyer
        // l'ancien la DÉPLACERAIT, et l'autre vente la perdrait.
        var uidLigne = l.uid;
        if (uidLigne == null || uidsLignesServeur.contains(uidLigne)) {
          uidLigne = nouvelUid();
          await (_db.update(_db.saleLines)..where((x) => x.id.equals(l.id)))
              .write(SaleLinesCompanion(uid: Value(uidLigne)));
        }
        await c.from('mirror_sale_lines').upsert({
          'uid': uidLigne,
          'sale_id': idServeur,
          'article_id': l.articleId,
          'article_name': l.articleName,
          'qty': l.qty,
          'unit_price_cents': l.unitPriceCents,
        }, onConflict: 'uid');
        lignesRendues++;
      }
    }

    return VerificationVentes(
      absentes: absentes,
      lignesRestaurees: lignesRendues,
      heuresCorrigees: heures,
      ventesVerifiees: locales.length,
    );
  }

  /// Renvoie au serveur des ventes absentes, à la demande du super admin.
  /// Chacune y est créée sous son uid : renvoyer deux fois ne la double
  /// pas. Renvoie le nombre envoyé.
  static Future<int> renvoyerVentes(List<int> idsLocaux) async {
    var n = 0;
    for (final id in idsLocaux) {
      await pushSaleOrThrow(id);
      n++;
    }
    return n;
  }

  /// La vente du serveur qui est cette vente locale envoyée avec un
  /// décalage de fuseau, s'il y en a une. Même numéro, même lieu, même
  /// paiement, et une heure décalée d'un nombre EXACT d'heures (1 à 3) :
  /// une coïncidence de ce genre, à la seconde, n'arrive pas par hasard.
  static int? _venteDecalee(Sale v, List<Map<String, dynamic>> candidates) {
    final secondes = v.soldAt.millisecondsSinceEpoch ~/ 1000;
    for (final s in candidates) {
      final heure = _parseDate(s['sold_at']);
      if (heure == null) continue;
      final ecart = heure.millisecondsSinceEpoch ~/ 1000 - secondes;
      if (ecart == 0 || ecart % 3600 != 0 || ecart.abs() > 3 * 3600) continue;
      if ((s['location'] as num).toInt() != v.location.index) continue;
      if ((s['payment'] as num).toInt() != v.payment.index) continue;
      return (s['id'] as num).toInt();
    }
    return null;
  }

  static String _signatureLigne(String nom, int qte, int prix) =>
      '${nom.trim().toLowerCase()}|$qte|$prix';

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
      final rows = await toutesLesPages(() => c
          .from('mirror_articles')
          .select('id, name, price_cents, category, active, image_path, '
              'track_stock, unit, stock_qty, threshold')
          .order('id'));
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
      final rows = await toutesLesPages(
          () => c.from('mirror_clients').select().order('id'));
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
                  firstSeenAt: Value(
                      _parseDate(r['first_seen_at']) ?? Horloge.maintenant()),
                  lastSeenAt: Value(
                      _parseDate(r['last_seen_at']) ?? Horloge.maintenant()),
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
      final rows = await toutesLesPages(
          () => c.from('mirror_payers').select().order('id'));
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
                  createdAt: Value(
                      _parseDate(r['created_at']) ?? Horloge.maintenant()),
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

  /// Supprime la vente du serveur, par son uid. Le numéro local ne
  /// suffisait pas : il désignait peut-être la vente d'un autre poste.
  /// Les lignes partent avec elle (clé étrangère en cascade).
  static Future<void> deleteSaleByUid(String? uid) async {
    final c = _c;
    if (c == null || uid == null) return;
    try {
      await c.from('mirror_sales').delete().eq('uid', uid);
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

      // Séjours facturés : renvoyés en bloc pour rattraper ceux qu'un
      // départ hors ligne n'a pas pu envoyer. Par uid, comme les ventes.
      await _pousserSejours(await (_db.select(_db.stays)
            ..where((s) => s.statut.equals(DbStayStatus.facture.index)))
          .get());
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
  ///
  /// Pas d'`id` : c'est le serveur qui numérote. `uid` est la clé.
  static Map<String, dynamic> _saleJson(Sale s, String uid,
          {int dejaPaye = 0}) =>
      {
        'uid': uid,
        'paid_cents': dejaPaye,
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

  /// [idServeur] : le numéro que le serveur a donné à la vente.
  static Map<String, dynamic> _lineJson(
          SaleLine l, String uidVente, int idServeur) =>
      {
        'uid': l.uid ?? uidLigneHerite(uidVente, l.id),
        'sale_id': idServeur,
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

  static const _articleTemoin = Article(
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

  /// Pas d'`id` : c'est le serveur qui numérote. `uid` est la clé.
  static Map<String, dynamic> _stayJson(Stay s, String uid) => {
        'uid': uid,
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

  /// [idServeur] : le numéro que le serveur a donné au séjour.
  static Map<String, dynamic> _stayRoomJson(
          StayRoom r, String uidSejour, int idServeur) =>
      {
        'uid': r.uid ?? uidLigneHerite(uidSejour, r.id),
        'stay_id': idServeur,
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
