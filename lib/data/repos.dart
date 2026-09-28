import 'dart:async';

import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart';

import '../core/auth.dart';
import '../core/room_type.dart';
import '../core/discount.dart';
import '../core/format.dart';
import '../services/accounts_service.dart';
import '../services/mirror_service.dart';
import '../services/stock_service.dart';
import '../core/temps.dart';
import 'database.dart';
import 'seed.dart';
import 'schema.dart';
import '../core/horloge.dart';
import '../services/ventes_outbox.dart';
import '../core/devise.dart';

// ─── Réglages (clé/valeur) ────────────────────────────────────────────────
//
// La table `settings` sert de coffre à réglages simples. Actuellement, on
// n'y stocke que le taux de change FC→USD utilisé sur les PDF (facture,
// rapport) pour afficher l'équivalent dollar.

class SettingsRepo {
  SettingsRepo(this._db);
  final AppDatabase _db;

  static const String kRate = 'fc_per_usd_rate';

  Future<void> _set(String key, String value) {
    return _db.into(_db.settings).insertOnConflictUpdate(
        SettingsCompanion(key: Value(key), value: Value(value)));
  }

  Future<String?> _get(String key) async {
    final row = await (_db.select(_db.settings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Taux courant FC pour 1 USD. Fallback [Currency.defaultRate].
  Future<double> getRate() async {
    final v = await _get(kRate);
    return double.tryParse(v ?? '') ?? Currency.defaultRate;
  }

  /// Change le taux ET recalcule les tarifs en francs.
  ///
  /// Les deux vont ensemble, et pas par commodité : `pricePerNightCents`
  /// est une valeur CALCULÉE, gardée en base parce que la caisse, le
  /// miroir et les rapports la lisent partout. La laisser derrière le
  /// taux, c'est facturer au cours d'avant-hier sans que rien ne le
  /// signale — le genre d'erreur qu'on ne découvre qu'en comptant la
  /// caisse.
  ///
  /// Les séjours DÉJÀ facturés ne bougent pas : ils portent leur propre
  /// taux, figé au check-out. C'est tout l'intérêt de l'avoir figé.
  Future<void> setRate(double rate) async {
    await _set(kRate, rate.toString());
    Currency.rate = rate;
    if (rate <= 0) return;
    await _db.customStatement(
      'UPDATE rooms SET price_per_night_cents = '
      'CAST(ROUND(price_usd_cents / 100.0 * ?) AS INTEGER) '
      'WHERE price_usd_cents > 0',
      [rate],
    );
  }

  /// Stream réactif pour mettre à jour l'UI dès qu'un admin change le taux.
  Stream<double> watchRate() {
    return (_db.select(_db.settings)..where((s) => s.key.equals(kRate)))
        .watch()
        .map((rows) => rows.isEmpty
            ? Currency.defaultRate
            : (double.tryParse(rows.first.value) ?? Currency.defaultRate));
  }
}

// ─── Users ──────────────────────────────────────────────────────────────

/// Comptes utilisateurs.
///
/// **Supabase est la source de vérité.** La table locale `users` n'est
/// qu'un cache : elle alimente l'écran de connexion, garde le hash qui
/// autorise la reconnexion hors-ligne, et héberge les comptes de secours
/// (`isLocalDefault`) qui, eux, ne quittent jamais le poste.
///
/// Toute écriture passe donc par [AccountsService], qui exige les
/// identifiants d'un admin revérifiés côté serveur. Aucune de ces
/// méthodes n'écrit « en local seulement » : une opération qui échoue
/// côté serveur ne doit pas laisser croire qu'elle a réussi.
class UsersRepo {
  UsersRepo(this._db);
  final AppDatabase _db;

  Stream<List<User>> watchAll() => _db.select(_db.users).watch();

  Future<List<User>> all() => _db.select(_db.users).get();

  /// Rafraîchit le cache local depuis Supabase.
  ///
  /// - Les comptes de secours locaux ne sont jamais touchés.
  /// - Le hash local est PRÉSERVÉ pour les comptes déjà connus (c'est
  ///   l'accès hors-ligne) ; un compte jamais vu ici reçoit un hash
  ///   sentinelle qui ne matche rien tant qu'il ne s'est pas connecté
  ///   une fois avec Internet.
  /// - Un compte absent du serveur est supprimé du cache : c'est ainsi
  ///   qu'un licenciement se propage sur tous les postes.
  ///
  /// Lève une [AccountException] si le serveur est injoignable —
  /// l'appelant affiche l'erreur, le cache reste inchangé.
  Future<int> syncFromCloud() async {
    final remote = await AccountsService.listAccounts();
    final local = await _db.select(_db.users).get();
    final byLogin = {for (final u in local) u.login.toLowerCase(): u};
    final remoteLogins = <String>{};
    var applied = 0;

    await _db.transaction(() async {
      for (final a in remote) {
        final key = a.login.toLowerCase();
        remoteLogins.add(key);
        final role =
            DbUserRole.values[a.role.clamp(0, DbUserRole.values.length - 1)];
        final existing = byLogin[key];
        if (existing == null) {
          await _db.into(_db.users).insert(
                UsersCompanion.insert(
                  fullName: a.fullName,
                  login: a.login,
                  passwordHash: kNoOfflineAccessHash,
                  role: role,
                  active: Value(a.active),
                  createdAt: Value(a.createdAt ?? Horloge.maintenant()),
                  lastLogin: Value(a.lastLogin),
                  syncedAt: Value(Horloge.maintenant()),
                ),
                mode: InsertMode.insertOrIgnore,
              );
        } else {
          if (existing.isLocalDefault) continue; // secours : intouchable
          await (_db.update(_db.users)..where((u) => u.id.equals(existing.id)))
              .write(UsersCompanion(
            fullName: Value(a.fullName),
            role: Value(role),
            active: Value(a.active),
            lastLogin: Value(a.lastLogin ?? existing.lastLogin),
            syncedAt: Value(Horloge.maintenant()),
          ));
        }
        applied++;
      }

      // Comptes disparus côté serveur → on retire l'accès ici aussi.
      //
      // MAIS uniquement ceux qui avaient DÉJÀ été synchronisés : leur
      // absence est alors une suppression volontaire. Un compte jamais
      // synchronisé (syncedAt null) est un compte historique pas encore
      // repris vers Supabase — le supprimer effacerait toute l'équipe
      // au premier clic sur « Synchroniser », avant la reprise.
      // Un compte absent du serveur n'existe plus : c'est ainsi qu'un
      // départ se propage sur tous les postes. Seuls les comptes de
      // secours y échappent — ils sont locaux par nature.
      for (final u in local) {
        if (u.isLocalDefault) continue;
        if (!remoteLogins.contains(u.login.toLowerCase())) {
          await (_db.delete(_db.users)..where((x) => x.id.equals(u.id))).go();
        }
      }
    });
    return applied;
  }

  /// Les comptes vivent EXCLUSIVEMENT sur Supabase.
  ///
  /// Seuls les trois comptes de secours (`reception`, `serveuse`,
  /// `admin`) sont locaux : ils existent pour qu'un poste coupé du
  /// réseau puisse encaisser, et ne montent jamais au serveur.
  ///
  /// Tout le reste — création, renommage, activation, mot de passe —
  /// passe par le serveur et échoue proprement s'il est injoignable.
  /// Écrire en local produirait deux vérités divergentes : un compte
  /// créé ici et inconnu ailleurs, ou un mot de passe changé sur un
  /// seul poste.
  ///
  /// La base locale ne garde qu'un CACHE DE LECTURE : la liste des
  /// comptes pour l'écran de connexion, et le hash bcrypt de ceux qui
  /// se sont déjà connectés ici — c'est ce qui permet de travailler
  /// hors ligne sans jamais devenir une source de vérité concurrente.

  Future<int> create({
    required ({String login, String password}) actor,
    required String fullName,
    required String login,
    required String password,
    required DbUserRole role,
  }) async {
    if (await _loginPris(login)) {
      throw const AccountException(
          AccountErrorKind.rejected, 'Cet identifiant est déjà utilisé.');
    }

    final id = await AccountsService.createAccount(
      actorLogin: actor.login,
      actorPassword: actor.password,
      login: login,
      fullName: fullName,
      password: password,
      role: role.index,
    );
    // Le compte existe côté serveur : il apparaît ici sans accès
    // hors-ligne tant qu'il ne s'est pas connecté une fois.
    await _db.into(_db.users).insert(
          UsersCompanion.insert(
            fullName: fullName.trim(),
            login: login.trim(),
            passwordHash: kNoOfflineAccessHash,
            role: role,
            syncedAt: Value(Horloge.maintenant()),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return id;
  }

  Future<bool> _loginPris(String login) async {
    final ex = await (_db.select(_db.users)
          ..where((u) => u.login.lower().equals(login.trim().toLowerCase())))
        .getSingleOrNull();
    return ex != null;
  }

  Future<void> setActive(
      {required ({String login, String password}) actor,
      required User target,
      required bool active}) async {
    _refuseLocalDefault(target, 'activer ou désactiver');
    await AccountsService.setActive(
      actorLogin: actor.login,
      actorPassword: actor.password,
      login: target.login,
      active: active,
    );
    await (_db.update(_db.users)..where((u) => u.id.equals(target.id))).write(
      UsersCompanion(
        active: Value(active),
        syncedAt: Value(Horloge.maintenant()),
      ),
    );
  }

  Future<void> resetPassword(
      {required ({String login, String password}) actor,
      required User target,
      required String newPassword}) async {
    if (target.isLocalDefault) {
      // Un compte de secours n'existe pas côté serveur : son code se
      // change localement, sur ce poste uniquement.
      await (_db.update(_db.users)..where((u) => u.id.equals(target.id))).write(
          UsersCompanion(
              passwordHash:
                  Value(BCrypt.hashpw(newPassword, BCrypt.gensalt()))));
      return;
    }
    await AccountsService.setPassword(
      actorLogin: actor.login,
      actorPassword: actor.password,
      login: target.login,
      newPassword: newPassword,
    );
    // Le hash local en cache ne vaut plus rien : on le neutralise pour
    // que l'employé se reconnecte une fois en ligne avec le nouveau mot
    // de passe (sinon l'ancien marcherait encore hors-ligne).
    await (_db.update(_db.users)..where((u) => u.id.equals(target.id))).write(
        UsersCompanion(
            passwordHash: const Value(kNoOfflineAccessHash),
            mustChangePassword: Value(newPassword == kMotDePasseProvisoire),
            syncedAt: Value(Horloge.maintenant())));
  }

  /// Changement de SON PROPRE mot de passe (écran Réglages).
  ///
  /// Ne demande aucun privilège : le serveur se contente de vérifier
  /// l'ancien mot de passe, fourni par la session. Le hash local est mis
  /// à jour avec le nouveau — l'employé garde donc son accès hors-ligne
  /// sur ce poste.
  Future<void> changeOwnPassword({
    required ({String login, String password}) actor,
    required User me,
    required String newPassword,
  }) async {
    if (!me.isLocalDefault) {
      await AccountsService.setPassword(
        actorLogin: actor.login,
        actorPassword: actor.password,
        login: me.login,
        newPassword: newPassword,
      );
    }
    await (_db.update(_db.users)..where((u) => u.id.equals(me.id))).write(
      UsersCompanion(
        passwordHash: Value(BCrypt.hashpw(newPassword, BCrypt.gensalt())),
        // Le provisoire est consommé : l'employé a choisi le sien.
        mustChangePassword: const Value(false),
        syncedAt: Value(Horloge.maintenant()),
      ),
    );
  }

  Future<void> rename(
      {required ({String login, String password}) actor,
      required User target,
      required String fullName}) async {
    if (!target.isLocalDefault) {
      await AccountsService.rename(
        actorLogin: actor.login,
        actorPassword: actor.password,
        login: target.login,
        fullName: fullName,
      );
    }
    await (_db.update(_db.users)..where((u) => u.id.equals(target.id)))
        .write(UsersCompanion(fullName: Value(fullName.trim())));
  }

  /// Supprime un compte côté serveur puis dans le cache local.
  Future<void> delete(
      {required ({String login, String password}) actor,
      required User target}) async {
    _refuseLocalDefault(target, 'supprimer');
    await AccountsService.deleteAccount(
      actorLogin: actor.login,
      actorPassword: actor.password,
      login: target.login,
    );
    await (_db.delete(_db.users)..where((u) => u.id.equals(target.id))).go();
  }

  void _refuseLocalDefault(User target, String verb) {
    if (target.isLocalDefault) {
      throw AccountException(
          AccountErrorKind.rejected,
          'Impossible de $verb un compte de secours : il sert justement '
          'à ouvrir l\'application quand le serveur est injoignable.');
    }
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
  }) async {
    await (_db.update(_db.articles)..where((a) => a.id.equals(id))).write(
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
    // Le gérant doit voir la fiche corrigée depuis n'importe où, tout
    // de suite — pas au prochain démarrage.
    unawaited(MirrorService.pushArticleById(id));
  }

  /// Ajuste la quantité en stock (delta +/-, jamais négatif).
  ///
  /// La quantité reste calculée ICI, volontairement. Une quantité est un
  /// fait physique constaté sur ce poste : les bouteilles sortent du
  /// frigo même quand le réseau est coupé. La rendre « exclusivement en
  /// ligne » obligerait soit à refuser de vendre pendant une coupure,
  /// soit à laisser l'inventaire se désynchroniser en silence.
  ///
  /// Ce qui devient immédiat, en revanche, c'est la REMONTÉE : le gérant
  /// voit le mouvement dans les secondes qui suivent, même à distance.
  /// Sans ça, un ravitaillement n'atteignait le miroir qu'au prochain
  /// démarrage de l'application.
  Future<void> adjustQty(int id, int delta, {String? reason}) =>
      StockService(_db).declarer(
        articleId: id,
        delta: delta,
        reason: reason ?? 'ajustement',
      );

  Future<void> deactivate(int id) async {
    await (_db.update(_db.articles)..where((a) => a.id.equals(id)))
        .write(const ArticlesCompanion(active: Value(false)));
    unawaited(MirrorService.pushArticleById(id));
  }
}

// ─── Clients (fidélité) ────────────────────────────────────────────────

class ClientsRepo {
  ClientsRepo(this._db);
  final AppDatabase _db;

  Stream<List<Client>> watchAll() {
    final q = _db.select(_db.clients)
      ..orderBy([(c) => OrderingTerm.desc(c.lastSeenAt)]);
    return q.watch();
  }

  Future<List<Client>> search(String query, {int limit = 10}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return (_db.select(_db.clients)
            ..orderBy([(c) => OrderingTerm.desc(c.lastSeenAt)])
            ..limit(limit))
          .get();
    }
    // Match par nom (LIKE case-insensitive) OU par téléphone (préfixe).
    return (_db.select(_db.clients)
          ..where((c) => c.fullName.lower().like('%$q%') | c.phone.like('$q%'))
          ..limit(limit))
        .get();
  }

  /// Trouve un client existant ou le crée si absent. Priorité au
  /// téléphone (clé unique), fallback nom (case-insensitive).
  Future<Client> findOrCreate({
    required String fullName,
    String? phone,
    String? email,
  }) async {
    final norm = fullName.trim();
    final normPhone = (phone ?? '').trim();
    Client? found;
    if (normPhone.isNotEmpty) {
      found = await (_db.select(_db.clients)
            ..where((c) => c.phone.equals(normPhone)))
          .getSingleOrNull();
    }
    if (found == null) {
      final byName = await (_db.select(_db.clients)
            ..where((c) => c.fullName.lower().equals(norm.toLowerCase())))
          .get();
      if (byName.isNotEmpty) found = byName.first;
    }
    if (found != null) {
      unawaited(MirrorService.pushClientById(found.id));
      return found;
    }
    final id = await _db.into(_db.clients).insert(ClientsCompanion.insert(
          fullName: norm,
          phone: normPhone.isEmpty ? const Value.absent() : Value(normPhone),
          email: (email == null || email.trim().isEmpty)
              ? const Value.absent()
              : Value(email.trim()),
        ));
    unawaited(MirrorService.pushClientById(id));
    return (_db.select(_db.clients)..where((c) => c.id.equals(id))).getSingle();
  }

  /// Enregistre une visite : incrémente le compteur, met à jour la date
  /// de dernière visite. Optionnel : ajoute au total dépensé.
  Future<void> recordVisit(int clientId, {int spentCents = 0}) async {
    final row = await (_db.select(_db.clients)
          ..where((c) => c.id.equals(clientId)))
        .getSingleOrNull();
    if (row == null) return;
    await (_db.update(_db.clients)..where((c) => c.id.equals(clientId))).write(
      ClientsCompanion(
        visitsCount: Value(row.visitsCount + 1),
        lastSeenAt: Value(Horloge.maintenant()),
        totalSpentCents: Value(row.totalSpentCents + spentCents),
      ),
    );
    unawaited(MirrorService.pushClientById(clientId));
  }

  /// Ajoute uniquement un montant dépensé (à la facturation), sans
  /// compter une visite en plus.
  Future<void> addSpending(int clientId, int cents) async {
    final row = await (_db.select(_db.clients)
          ..where((c) => c.id.equals(clientId)))
        .getSingleOrNull();
    if (row == null) return;
    await (_db.update(_db.clients)..where((c) => c.id.equals(clientId))).write(
      ClientsCompanion(
        totalSpentCents: Value(row.totalSpentCents + cents),
        lastSeenAt: Value(Horloge.maintenant()),
      ),
    );
    unawaited(MirrorService.pushClientById(clientId));
  }

  Future<void> updateInfo({
    required int id,
    String? fullName,
    String? phone,
    String? email,
    String? notes,
  }) async {
    await (_db.update(_db.clients)..where((c) => c.id.equals(id))).write(
      ClientsCompanion(
        fullName: fullName == null ? const Value.absent() : Value(fullName),
        phone: phone == null
            ? const Value.absent()
            : Value(phone.trim().isEmpty ? null : phone.trim()),
        email: email == null
            ? const Value.absent()
            : Value(email.trim().isEmpty ? null : email.trim()),
        notes: notes == null
            ? const Value.absent()
            : Value(notes.trim().isEmpty ? null : notes.trim()),
      ),
    );
    unawaited(MirrorService.pushClientById(id));
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.clients)..where((c) => c.id.equals(id))).go();
    unawaited(MirrorService.deleteClientById(id));
  }
}

// ─── Payeurs (prise en charge société / privée) ────────────────────────

class PayersRepo {
  PayersRepo(this._db);
  final AppDatabase _db;

  Stream<List<Payer>> watchAll() {
    final q = _db.select(_db.payers)
      ..orderBy([(p) => OrderingTerm.asc(p.name)]);
    return q.watch();
  }

  Future<List<Payer>> search(String query, {int limit = 10}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return (_db.select(_db.payers)
            ..orderBy([(p) => OrderingTerm.asc(p.name)])
            ..limit(limit))
          .get();
    }
    return (_db.select(_db.payers)
          ..where((p) => p.name.lower().like('%$q%'))
          ..limit(limit))
        .get();
  }

  Future<Payer?> byId(int id) =>
      (_db.select(_db.payers)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<int> create({
    required String name,
    required DbPayerType type,
    String? taxId,
    String? address,
    String? contact,
    String? notes,
  }) async {
    final id = await _db.into(_db.payers).insert(PayersCompanion.insert(
          name: name.trim(),
          type: Value(type),
          taxId: taxId == null || taxId.trim().isEmpty
              ? const Value.absent()
              : Value(taxId.trim()),
          address: address == null || address.trim().isEmpty
              ? const Value.absent()
              : Value(address.trim()),
          contact: contact == null || contact.trim().isEmpty
              ? const Value.absent()
              : Value(contact.trim()),
          notes: notes == null || notes.trim().isEmpty
              ? const Value.absent()
              : Value(notes.trim()),
        ));
    unawaited(MirrorService.pushPayerById(id));
    return id;
  }

  Future<void> updateInfo({
    required int id,
    String? name,
    DbPayerType? type,
    String? taxId,
    String? address,
    String? contact,
    String? notes,
  }) async {
    await (_db.update(_db.payers)..where((p) => p.id.equals(id))).write(
      PayersCompanion(
        name: name == null ? const Value.absent() : Value(name.trim()),
        type: type == null ? const Value.absent() : Value(type),
        taxId: taxId == null
            ? const Value.absent()
            : Value(taxId.trim().isEmpty ? null : taxId.trim()),
        address: address == null
            ? const Value.absent()
            : Value(address.trim().isEmpty ? null : address.trim()),
        contact: contact == null
            ? const Value.absent()
            : Value(contact.trim().isEmpty ? null : contact.trim()),
        notes: notes == null
            ? const Value.absent()
            : Value(notes.trim().isEmpty ? null : notes.trim()),
      ),
    );
    unawaited(MirrorService.pushPayerById(id));
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.payers)..where((p) => p.id.equals(id))).go();
    unawaited(MirrorService.deletePayerById(id));
  }
}

// ─── Réservations futures ──────────────────────────────────────────────

/// Réservation avec ses chambres.
class ReservationWithRooms {
  final Reservation reservation;
  final List<ReservationRoom> rooms;
  const ReservationWithRooms(this.reservation, this.rooms);

  int nights() {
    final r = reservation;
    final d = r.checkoutDate.difference(r.checkinDate).inDays;
    return d < 1 ? 1 : d;
  }

  int estimatedTotalCents() =>
      rooms.fold(0, (s, r) => s + r.pricePerNightCents) * nights();
}

class ReservationsRepo {
  ReservationsRepo(this._db);
  final AppDatabase _db;

  Stream<List<ReservationWithRooms>> watchAll() {
    final q = _db.select(_db.reservations)
      ..orderBy([(r) => OrderingTerm.asc(r.checkinDate)]);
    return q.watch().asyncMap(_hydrate);
  }

  /// Réservations à venir (checkinDate >= aujourd'hui, non annulées).
  Stream<List<ReservationWithRooms>> watchUpcoming() {
    final startOfDay = debutDeJourneeLubumbashi();
    final q = _db.select(_db.reservations)
      ..where((r) =>
          r.checkinDate.isBiggerOrEqualValue(startOfDay) &
          r.status.isNotIn([
            DbReservationStatus.cancelled.index,
            DbReservationStatus.checkedIn.index,
          ]))
      ..orderBy([(r) => OrderingTerm.asc(r.checkinDate)]);
    return q.watch().asyncMap(_hydrate);
  }

  Future<ReservationWithRooms?> byId(int id) async {
    final r = await (_db.select(_db.reservations)
          ..where((x) => x.id.equals(id)))
        .getSingleOrNull();
    if (r == null) return null;
    final rooms = await (_db.select(_db.reservationRooms)
          ..where((x) => x.reservationId.equals(id)))
        .get();
    return ReservationWithRooms(r, rooms);
  }

  /// Crée une réservation. Génère un numéro de type RSV-YYYYMMDD-HHMM-XX.
  Future<int> create({
    required List<({String number, int pricePerNightCents})> rooms,
    required String guestFullName,
    String? guestPhone,
    String? guestEmail,
    int? payerId,
    required DateTime checkinDate,
    required DateTime checkoutDate,
    int depositCents = 0,
    String? note,
    String? createdByLogin,
  }) async {
    if (rooms.isEmpty) throw ArgumentError('Aucune chambre sélectionnée');
    if (!checkoutDate.isAfter(checkinDate)) {
      throw ArgumentError('Date de départ doit être après l\'arrivée');
    }
    final ts = Horloge.maintenant();
    final ref =
        'RSV-${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}'
        '-${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}'
        '-${(ts.millisecond % 100).toString().padLeft(2, '0')}';
    return _db.transaction(() async {
      final id = await _db.into(_db.reservations).insert(
            ReservationsCompanion.insert(
              reservationNumber: ref,
              checkinDate: checkinDate,
              checkoutDate: checkoutDate,
              guestFullName: guestFullName,
              guestPhone:
                  guestPhone == null ? const Value.absent() : Value(guestPhone),
              guestEmail:
                  guestEmail == null ? const Value.absent() : Value(guestEmail),
              payerId: payerId == null ? const Value.absent() : Value(payerId),
              depositCents: Value(depositCents),
              note: note == null ? const Value.absent() : Value(note),
              createdByLogin: createdByLogin == null
                  ? const Value.absent()
                  : Value(createdByLogin),
            ),
          );
      for (final r in rooms) {
        await _db.into(_db.reservationRooms).insert(
              ReservationRoomsCompanion.insert(
                reservationId: id,
                roomNumber: r.number,
                pricePerNightCents: r.pricePerNightCents,
              ),
            );
      }
      return id;
    });
  }

  Future<void> cancel(int id, String? reason) async {
    await (_db.update(_db.reservations)..where((r) => r.id.equals(id))).write(
      ReservationsCompanion(
        status: const Value(DbReservationStatus.cancelled),
        cancelledAt: Value(Horloge.maintenant()),
        cancelReason: reason == null ? const Value.absent() : Value(reason),
      ),
    );
  }

  /// Marque la réservation comme "arrivée effectuée" et retourne les
  /// chambres à check-in-er via RoomsRepo. La création du séjour concret
  /// (rooms.checkIn) est laissée à l'appelant pour garder ce repo mince.
  Future<void> markCheckedIn(int id, {int? stayId}) async {
    await (_db.update(_db.reservations)..where((r) => r.id.equals(id))).write(
      ReservationsCompanion(
        status: const Value(DbReservationStatus.checkedIn),
        stayId: stayId == null ? const Value.absent() : Value(stayId),
      ),
    );
  }

  Future<void> updateInfo({
    required int id,
    required DateTime checkinDate,
    required DateTime checkoutDate,
    required String guestFullName,
    String? guestPhone,
    String? guestEmail,
    int? payerId,
    int depositCents = 0,
    String? note,
  }) async {
    await (_db.update(_db.reservations)..where((r) => r.id.equals(id))).write(
      ReservationsCompanion(
        checkinDate: Value(checkinDate),
        checkoutDate: Value(checkoutDate),
        guestFullName: Value(guestFullName),
        guestPhone: Value(guestPhone),
        guestEmail: Value(guestEmail),
        payerId: Value(payerId),
        depositCents: Value(depositCents),
        note: Value(note),
      ),
    );
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.reservations)..where((r) => r.id.equals(id))).go();
  }

  Future<List<ReservationWithRooms>> _hydrate(
      List<Reservation> reservations) async {
    if (reservations.isEmpty) return [];
    final ids = reservations.map((r) => r.id).toList();
    final rooms = await (_db.select(_db.reservationRooms)
          ..where((r) => r.reservationId.isIn(ids)))
        .get();
    final byRes = <int, List<ReservationRoom>>{};
    for (final r in rooms) {
      byRes.putIfAbsent(r.reservationId, () => []).add(r);
    }
    return [
      for (final r in reservations)
        ReservationWithRooms(r, byRes[r.id] ?? const []),
    ];
  }
}

// ─── Stays (historique séjours pour re-facturation) ────────────────────

/// Un séjour persisté avec ses chambres — snapshot utilisé pour
/// régénérer la facture PDF depuis l'historique.
class StayWithRooms {
  final Stay stay;
  final List<StayRoom> rooms;
  const StayWithRooms(this.stay, this.rooms);

  int get totalCents =>
      (stay.subtotalCents - stay.remiseCents).clamp(0, 1 << 40);

  /// Remise telle qu'elle a été saisie (type, base, motif) — permet de
  /// réafficher « 10 % sur l'hébergement · Client fidèle » à l'identique
  /// dans l'historique et sur la facture régénérée.
  Discount get discount => Discount.fromDb(
        kindIndex: stay.remiseKind,
        value: stay.remiseValue,
        baseIndex: stay.remiseBase,
        reason: stay.remiseReason,
      );

  /// Économie liée aux tarifs négociés au check-in (hors remise de
  /// facturation), déjà déduite du sous-total.
  int get negotiatedSavingCents => rooms.fold(0, (sum, r) {
        final list = r.listPriceCents;
        if (list == null || list <= r.pricePerNightCents) return sum;
        return sum + (list - r.pricePerNightCents) * r.nights;
      });
}

class StaysRepo {
  StaysRepo(this._db);
  final AppDatabase _db;

  Stream<List<StayWithRooms>> watchRecent({int days = 90}) {
    final since = Horloge.maintenant().subtract(Duration(days: days));
    final q = _db.select(_db.stays)
      ..where((s) => s.generatedAt.isBiggerOrEqualValue(since))
      ..orderBy([(s) => OrderingTerm.desc(s.generatedAt)]);
    return q.watch().asyncMap(_hydrate);
  }

  Future<List<StayWithRooms>> allRecent({int days = 90}) {
    final since = Horloge.maintenant().subtract(Duration(days: days));
    return (_db.select(_db.stays)
          ..where((s) => s.generatedAt.isBiggerOrEqualValue(since))
          ..orderBy([(s) => OrderingTerm.desc(s.generatedAt)]))
        .get()
        .then(_hydrate);
  }

  Future<StayWithRooms?> byId(int id) async {
    final s = await (_db.select(_db.stays)..where((x) => x.id.equals(id)))
        .getSingleOrNull();
    if (s == null) return null;
    final rs = await (_db.select(_db.stayRooms)
          ..where((r) => r.stayId.equals(id)))
        .get();
    return StayWithRooms(s, rs);
  }

  /// Persiste un séjour + ses chambres en une seule transaction. Retourne
  /// l'id du séjour créé.
  Future<int> record({
    required String receiptNumber,
    String? reservationNumber,
    required DateTime generatedAt,
    required DateTime checkinAt,
    required DateTime checkoutAt,
    required String guestFullName,
    String? guestNationality,
    String? guestPhone,
    String? guestEmail,
    String? payerName,
    String? payerTaxId,
    String? payerAddress,
    String? payerContact,
    required int subtotalCents,
    int remiseCents = 0,
    Discount discount = Discount.none,
    int acompteFcCents = 0,
    int acompteUsdCents = 0,
    int paymentMode = 0,
    String? stayGroup,
    String? serverLogin,
    String? note,
    String extrasJson = '[]',
    int clientVisitsAtCheckout = 0,
    required List<
            ({
              String number,
              String type,
              DateTime checkinAt,
              DateTime checkoutAt,
              int pricePerNightCents,
              int? listPriceCents,
              int nights,
            })>
        rooms,
  }) async {
    return _db.transaction(() async {
      final stayId = await _db.into(_db.stays).insert(StaysCompanion.insert(
            // Le taux du jour, figé ici et plus jamais touché. Sans lui,
            // réimprimer cette facture dans six mois annoncerait un
            // total en dollars que le client n'a jamais payé.
            fcPerUsdCents: Value(tauxCourantEnCents()),
            receiptNumber: receiptNumber,
            reservationNumber: reservationNumber == null
                ? const Value.absent()
                : Value(reservationNumber),
            generatedAt: Value(generatedAt),
            checkinAt: checkinAt,
            checkoutAt: checkoutAt,
            guestFullName: guestFullName,
            guestNationality: guestNationality == null
                ? const Value.absent()
                : Value(guestNationality),
            guestPhone:
                guestPhone == null ? const Value.absent() : Value(guestPhone),
            guestEmail:
                guestEmail == null ? const Value.absent() : Value(guestEmail),
            payerName:
                payerName == null ? const Value.absent() : Value(payerName),
            payerTaxId:
                payerTaxId == null ? const Value.absent() : Value(payerTaxId),
            payerAddress: payerAddress == null
                ? const Value.absent()
                : Value(payerAddress),
            payerContact: payerContact == null
                ? const Value.absent()
                : Value(payerContact),
            subtotalCents: subtotalCents,
            remiseCents: Value(remiseCents),
            remiseKind: Value(discount.kind.index),
            remiseValue: Value(discount.value),
            remiseBase: Value(discount.base.index),
            remiseReason:
                (discount.reason == null || discount.reason!.trim().isEmpty)
                    ? const Value.absent()
                    : Value(discount.reason!.trim()),
            acompteFcCents: Value(acompteFcCents),
            acompteUsdCents: Value(acompteUsdCents),
            paymentMode: Value(paymentMode),
            stayGroup:
                stayGroup == null ? const Value.absent() : Value(stayGroup),
            serverLogin:
                serverLogin == null ? const Value.absent() : Value(serverLogin),
            note: note == null ? const Value.absent() : Value(note),
            extrasJson: Value(extrasJson),
            clientVisitsAtCheckout: Value(clientVisitsAtCheckout),
          ));
      for (final r in rooms) {
        await _db.into(_db.stayRooms).insert(StayRoomsCompanion.insert(
              stayId: stayId,
              roomNumber: r.number,
              roomType: r.type,
              checkinAt: r.checkinAt,
              checkoutAt: r.checkoutAt,
              pricePerNightCents: r.pricePerNightCents,
              // Le prix en dollars est recalculé au taux du jour plutôt
              // que transmis : l'appelant raisonne encore en francs, et
              // c'est le même taux qui vient d'être figé sur le séjour.
              priceUsdCents: Value(fcVersUsd(r.pricePerNightCents)),
              listPriceCents: Value(r.listPriceCents),
              listUsdCents: Value(r.listPriceCents == null
                  ? null
                  : fcVersUsd(r.listPriceCents!)),
              nights: r.nights,
            ));
      }
      return stayId;
    }).then((stayId) {
      // Le séjour part vers le miroir : c'est ce qui permet au tableau
      // de bord de Pamela d'afficher un chiffre d'affaires hôtel.
      // `unawaited` volontairement — libérer une chambre ne doit jamais
      // attendre le réseau. En cas d'échec, le prochain `syncAll`
      // rattrape.
      unawaited(MirrorService.pushStayById(stayId));
      return stayId;
    });
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.stays)..where((s) => s.id.equals(id))).go();
  }

  Future<List<StayWithRooms>> _hydrate(List<Stay> stays) async {
    if (stays.isEmpty) return [];
    final ids = stays.map((s) => s.id).toList();
    final rooms = await (_db.select(_db.stayRooms)
          ..where((r) => r.stayId.isIn(ids)))
        .get();
    final byStay = <int, List<StayRoom>>{};
    for (final r in rooms) {
      byStay.putIfAbsent(r.stayId, () => []).add(r);
    }
    return [
      for (final s in stays) StayWithRooms(s, byStay[s.id] ?? const []),
    ];
  }
}

// Sentinel pour distinguer "ne pas toucher" de "mettre à null" dans les
// paramètres optionnels de updateInfo (imagePath en particulier).
const Object _unset = Object();

// ─── Rooms ──────────────────────────────────────────────────────────────

class RoomsRepo {
  RoomsRepo(this._db);
  final AppDatabase _db;

  Stream<List<Room>> watchAll() {
    final query = _db.select(_db.rooms)
      ..orderBy([(r) => OrderingTerm.asc(r.number)]);
    return query.watch();
  }

  /// [negotiatedPriceCents] : tarif/nuit consenti pour CE séjour
  /// uniquement (null → tarif catalogue). Le catalogue n'est jamais
  /// modifié : l'écart devient une remise visible sur la facture.
  Future<void> checkIn(String number, String guest, DateTime checkout,
      {String? note, int? payerId, int? negotiatedPriceCents}) async {
    await (_db.update(_db.rooms)..where((r) => r.number.equals(number))).write(
      RoomsCompanion(
        status: const Value(DbRoomStatus.occupee),
        currentGuest: Value(guest),
        checkoutDate: Value(checkout),
        checkinNote: Value(
            (note != null && note.trim().isNotEmpty) ? note.trim() : null),
        checkinAt: Value(Horloge.maintenant()),
        stayGroup: const Value(null),
        payerId: Value(payerId),
        negotiatedPriceCents: Value(
            (negotiatedPriceCents != null && negotiatedPriceCents > 0)
                ? negotiatedPriceCents
                : null),
      ),
    );
    unawaited(MirrorService.pushRoomByNumber(number));
  }

  /// Check-in de plusieurs chambres en une fois pour un même payeur
  /// (entreprise, groupe). Toutes les chambres partagent :
  ///   - le même `stayGroup` (ex. GRP-20260824-1215-01)
  ///   - le même nom (entreprise / responsable)
  ///   - la même date de départ initiale (chaque chambre pourra sortir
  ///     séparément ensuite)
  ///   - la même note
  ///
  /// Retourne le `stayGroup` généré (utile pour navigation UI).
  Future<String> groupCheckIn({
    required List<String> numbers,
    required String guest,
    required DateTime checkout,
    String? note,
    int? payerId,

    /// Tarif négocié par chambre (numéro → cents FC/nuit). Une chambre
    /// absente de la map garde son tarif catalogue.
    Map<String, int> negotiatedPrices = const {},
  }) async {
    final ts = Horloge.maintenant();
    final ref =
        'GRP-${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}'
        '-${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}'
        '-${(ts.millisecond % 100).toString().padLeft(2, '0')}';
    await _db.transaction(() async {
      for (final n in numbers) {
        await (_db.update(_db.rooms)..where((r) => r.number.equals(n))).write(
          RoomsCompanion(
            status: const Value(DbRoomStatus.occupee),
            currentGuest: Value(guest),
            checkoutDate: Value(checkout),
            checkinNote: Value(
                (note != null && note.trim().isNotEmpty) ? note.trim() : null),
            checkinAt: Value(ts),
            stayGroup: Value(ref),
            payerId: Value(payerId),
            negotiatedPriceCents: Value(
                (negotiatedPrices[n] != null && negotiatedPrices[n]! > 0)
                    ? negotiatedPrices[n]
                    : null),
          ),
        );
      }
    });
    // Push miroir en parallèle (best-effort).
    for (final n in numbers) {
      unawaited(MirrorService.pushRoomByNumber(n));
    }
    return ref;
  }

  /// Renvoie toutes les chambres actuellement occupées faisant partie
  /// d'un même séjour groupé.
  Future<List<Room>> membersOfGroup(String stayGroup) {
    return (_db.select(_db.rooms)..where((r) => r.stayGroup.equals(stayGroup)))
        .get();
  }

  Future<void> checkOut(String number) async {
    await (_db.update(_db.rooms)..where((r) => r.number.equals(number))).write(
      const RoomsCompanion(
        status: Value(DbRoomStatus.nettoyage),
        currentGuest: Value(null),
        checkoutDate: Value(null),
        checkinNote: Value(null),
        checkinAt: Value(null),
        stayGroup: Value(null),
        payerId: Value(null),
        negotiatedPriceCents: Value(null),
      ),
    );
    unawaited(MirrorService.pushRoomByNumber(number));
  }

  Future<void> setStatus(String number, DbRoomStatus status) async {
    await (_db.update(_db.rooms)..where((r) => r.number.equals(number)))
        .write(RoomsCompanion(status: Value(status)));
    unawaited(MirrorService.pushRoomByNumber(number));
  }

  Future<void> create({
    required String number,
    required String type,

    /// Tarif de la nuit en CENTS DE DOLLAR : c'est le prix annoncé au
    /// client, donc la seule valeur saisie. Le franc en découle.
    required int priceUsdCents,
    String? imagePath,
  }) async {
    await _db.into(_db.rooms).insert(RoomsCompanion.insert(
          number: number,
          // Normalisé ici plutôt qu'à l'écran : toute création passe par
          // ce point, l'écran non (imports, reprises, futurs appels).
          type: normalizeRoomType(type) ?? kTypeChambreParDefaut,
          priceUsdCents: Value(priceUsdCents),
          // Conversion au taux courant, recalculée à chaque changement
          // de taux (cf. SettingsRepo.setRate). C'est cette valeur-là que
          // lisent la caisse, le miroir et les rapports.
          pricePerNightCents: usdVersFc(priceUsdCents),
          status: DbRoomStatus.libre,
          imagePath: imagePath == null || imagePath.isEmpty
              ? const Value.absent()
              : Value(imagePath),
        ));
    unawaited(MirrorService.pushRoomByNumber(number));
  }

  Future<void> updateInfo({
    required String number,
    required String type,

    /// Tarif de la nuit en CENTS DE DOLLAR.
    required int priceUsdCents,
    // Utiliser un sentinel : null → ne rien toucher, "" → retirer,
    // sinon → mettre à jour.
    Object? imagePath = _unset,
  }) async {
    await (_db.update(_db.rooms)..where((r) => r.number.equals(number))).write(
      RoomsCompanion(
        type: Value(normalizeRoomType(type) ?? kTypeChambreParDefaut),
        priceUsdCents: Value(priceUsdCents),
        pricePerNightCents: Value(usdVersFc(priceUsdCents)),
        imagePath: identical(imagePath, _unset)
            ? const Value.absent()
            : Value(imagePath as String?),
      ),
    );
    unawaited(MirrorService.pushRoomByNumber(number));
  }

  Future<void> delete(String number) async {
    await (_db.delete(_db.rooms)..where((r) => r.number.equals(number))).go();
    unawaited(MirrorService.deleteRoomByNumber(number));
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
    final since = Horloge.maintenant().subtract(Duration(days: days));
    final query = _db.select(_db.sales)
      ..where((s) => s.soldAt.isBiggerOrEqualValue(since))
      ..orderBy([(s) => OrderingTerm.desc(s.soldAt)]);
    return query.watch().asyncMap(_hydrate);
  }

  /// Ventes sur un intervalle de dates précis (pour les rapports).
  Future<List<SaleWithLines>> rangeSales(DateTime start, DateTime end) async {
    final sales = await (_db.select(_db.sales)
          ..where((s) =>
              s.soldAt.isBiggerOrEqualValue(start) &
              s.soldAt.isSmallerOrEqualValue(end))
          ..orderBy([(s) => OrderingTerm.desc(s.soldAt)]))
        .get();
    return _hydrate(sales);
  }

  /// Dettes en cours (vente à crédit non encore réglée).
  Stream<List<SaleWithLines>> watchOutstandingDebts() {
    final query = _db.select(_db.sales)
      ..where((s) => s.onCredit.equals(true) & s.settledAt.isNull())
      ..orderBy([(s) => OrderingTerm.desc(s.soldAt)]);
    return query.watch().asyncMap(_hydrate);
  }

  /// Toutes les ventes taggées à une chambre depuis une date donnée
  /// (utilisé pour la facture de séjour).
  Future<List<SaleWithLines>> forRoomsSince(
      List<String> roomNumbers, DateTime since) async {
    if (roomNumbers.isEmpty) return [];
    final sales = await (_db.select(_db.sales)
          ..where((s) =>
              s.roomNumber.isIn(roomNumbers) &
              s.soldAt.isBiggerOrEqualValue(since))
          ..orderBy([(s) => OrderingTerm.asc(s.soldAt)]))
        .get();
    return _hydrate(sales);
  }

  /// Consommations À FACTURER au check-out : rattachées à la chambre et
  /// PAS ENCORE PAYÉES.
  ///
  /// La distinction est capitale. Un client qui commande une Primus au
  /// bar et la règle en espèces sur place a une vente rattachée à sa
  /// chambre — mais déjà payée. L'ancienne version reprenait TOUTES les
  /// ventes de la chambre : il la payait une seconde fois sur sa facture
  /// de sortie.
  ///
  /// Seules comptent ici les ventes mises sur la note : `onCredit` et
  /// pas encore réglées.
  Future<List<SaleWithLines>> unpaidForRoomsSince(
      List<String> roomNumbers, DateTime since) async {
    if (roomNumbers.isEmpty) return [];
    final sales = await (_db.select(_db.sales)
          ..where((s) =>
              s.roomNumber.isIn(roomNumbers) &
              s.soldAt.isBiggerOrEqualValue(since) &
              s.onCredit.equals(true) &
              s.settledAt.isNull())
          ..orderBy([(s) => OrderingTerm.asc(s.soldAt)]))
        .get();
    return _hydrate(sales);
  }

  /// Solde une dette d'un seul coup.
  ///
  /// Conservée pour les appels qui règlent forcément la totalité — le
  /// check-out d'un séjour, par exemple, où la facture est payée en
  /// entier ou pas émise. Elle passe par [encaisserSurDette] pour que le
  /// versement laisse la même trace que les autres.
  Future<void> settleDebt(int saleId, DbPayment payment,
      {String? parLogin}) async {
    final reste = await resteADevoir(saleId);
    await encaisserSurDette(
      saleId: saleId,
      montantCents: reste > 0 ? reste : 0,
      payment: payment,
      parLogin: parLogin,
    );
  }

  /// Total d'une vente, en cents.
  Future<int> totalVente(int saleId) async {
    final l = _db.saleLines;
    final somme = (l.qty * l.unitPriceCents).sum();
    final q = _db.selectOnly(l)
      ..addColumns([somme])
      ..where(l.saleId.equals(saleId));
    return (await q.getSingle()).read(somme) ?? 0;
  }

  /// Somme déjà encaissée sur une dette.
  Future<int> dejaPaye(int saleId) async {
    final d = _db.debtPayments;
    final somme = d.amountCents.sum();
    final q = _db.selectOnly(d)
      ..addColumns([somme])
      ..where(d.saleId.equals(saleId));
    return (await q.getSingle()).read(somme) ?? 0;
  }

  /// Ce qu'il reste à recouvrer sur une vente. Jamais négatif : un
  /// trop-perçu est une anomalie à traiter, pas une dette inversée.
  Future<int> resteADevoir(int saleId) async {
    final reste = await totalVente(saleId) - await dejaPaye(saleId);
    return reste > 0 ? reste : 0;
  }

  /// Enregistre un versement sur une dette.
  ///
  /// Le versement est le fait ; `settledAt` n'en est que le résumé. On
  /// écrit donc les deux dans la MÊME transaction : une coupure entre
  /// les deux laisserait une dette soldée sans versement, ou l'inverse,
  /// et il faudrait un inventaire de caisse pour savoir laquelle croire.
  ///
  /// Un versement qui couvre le reste solde la vente. Un versement
  /// partiel ne la solde pas — c'est tout l'intérêt.
  Future<void> encaisserSurDette({
    required int saleId,
    required int montantCents,
    required DbPayment payment,
    String? parLogin,
    String? note,
  }) async {
    if (montantCents < 0) {
      throw ArgumentError("Un versement ne peut pas être négatif.");
    }
    await _db.transaction(() async {
      if (montantCents > 0) {
        await _db.into(_db.debtPayments).insert(DebtPaymentsCompanion.insert(
              saleId: saleId,
              amountCents: montantCents,
              payment: payment,
              receivedByLogin: Value(parLogin),
              note: Value(note),
              // Explicite : le défaut SQL prendrait l'horloge du système.
              // Un versement mal daté, c'est une caisse qui ne tombe pas
              // juste le soir.
              receivedAt: Value(Horloge.maintenant()),
            ));
      }
      final reste = await resteADevoir(saleId);
      await (_db.update(_db.sales)..where((s) => s.id.equals(saleId))).write(
        SalesCompanion(
          // Soldée seulement si plus rien n'est dû.
          settledAt: reste <= 0 ? Value(Horloge.maintenant()) : const Value(null),
          payment: Value(payment),
        ),
      );
    });
    unawaited(VentesOutbox(_db).pousser(saleId));
  }

  /// Versements reçus sur une vente, du plus ancien au plus récent.
  Future<List<DebtPayment>> versements(int saleId) =>
      (_db.select(_db.debtPayments)
            ..where((d) => d.saleId.equals(saleId))
            ..orderBy([(d) => OrderingTerm.asc(d.receivedAt)]))
          .get();

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

  /// Nombre total de ventes en base (pour affichage de confirmation).
  Future<int> countAll() async {
    final q = _db.selectOnly(_db.sales)..addColumns([_db.sales.id.count()]);
    final row = await q.getSingle();
    return row.read(_db.sales.id.count()) ?? 0;
  }

  /// PURGE TOTALE des ventes + lignes de vente. **NE RESTAURE PAS** les
  /// stocks (car ce serait absurde en fin de phase de test — les stocks
  /// affichés en base sont ceux à jour, on ne veut PAS les remettre au
  /// "seed initial + toutes ventes annulées"). Cette méthode est
  /// destinée exclusivement au **reset transactions pré-prod**.
  ///
  /// Retourne le nombre de ventes supprimées.
  Future<int> wipeAllSales() async {
    return await _db.transaction<int>(() async {
      final count = await countAll();
      await _db.delete(_db.saleLines).go();
      await _db.delete(_db.sales).go();
      return count;
    });
  }

  /// Supprime une vente et ses lignes. Restaure le stock des articles suivis
  /// (miroir exact de [createSale], qui l'avait décrémenté). Le tout dans une
  /// transaction pour rester cohérent.
  Future<void> deleteSale(int saleId) async {
    await _db.transaction(() async {
      final lines = await (_db.select(_db.saleLines)
            ..where((l) => l.saleId.equals(saleId)))
          .get();
      for (final line in lines) {
        final articleId = line.articleId;
        if (articleId == null) continue; // article supprimé : rien à restaurer.
        final art = await (_db.select(_db.articles)
              ..where((a) => a.id.equals(articleId)))
            .getSingleOrNull();
        if (art == null || !art.trackStock) continue;
        await (_db.update(_db.articles)..where((a) => a.id.equals(art.id)))
            .write(ArticlesCompanion(stockQty: Value(art.stockQty + line.qty)));
      }
      await (_db.delete(_db.saleLines)..where((l) => l.saleId.equals(saleId)))
          .go();
      await (_db.delete(_db.sales)..where((s) => s.id.equals(saleId))).go();
    });
  }

  Future<int> createSale({
    required Map<int, int> articleQuantities, // articleId -> qty
    required DbPayment payment,
    required DbLocation location,
    required int? serverUserId,
    String? customerName,
    String? roomNumber,
    bool onCredit = false,
    String? note,
  }) async {
    final sorties = <int, int>{};
    return _db.transaction(() async {
      final saleId = await _db.into(_db.sales).insert(SalesCompanion.insert(
            soldAt: Horloge.maintenant(),
            payment: payment,
            location: Value(location),
            serverUserId: Value(serverUserId),
            customerName: Value(customerName),
            roomNumber: Value(roomNumber),
            onCredit: Value(onCredit),
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
        // Sortie de stock déclarée comme un DELTA, pas comme une
        // quantité. Deux postes qui vendent pendant la même coupure
        // s'additionnent au lieu de s'écraser.
        //
        // Le négatif n'est plus borné à zéro : si le stock initial était
        // faux, le montrer vaut mieux que le cacher. Les bouteilles sont
        // sorties du frigo — l'écart est une information, pas une
        // erreur à masquer.
        if (art.trackStock) {
          sorties[art.id] = entry.value;
        }
      }
      return saleId;
    }).then((saleId) async {
      // Hors de la transaction : un mouvement doit pouvoir partir au
      // serveur sans tenir la base ouverte.
      for (final e in sorties.entries) {
        await StockService(_db).declarer(
          articleId: e.key,
          delta: -e.value,
          reason: 'vente',
        );
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
    final today = debutDeJourneeLubumbashi();
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
    final lines = await (_db.select(_db.saleLines)
          ..where((l) => l.saleId.isIn(ids)))
        .get();
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
      final d = debutDeJourneeLubumbashi(s.soldAt);
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
    final result = buckets.values.toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    return result;
  }
}
