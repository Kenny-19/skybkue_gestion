import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/schema.dart';

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.instance;
  ref.onDispose(db.close);
  return db;
});

class AuthState {
  final User? user;
  const AuthState(this.user);
  bool get isLoggedIn => user != null;
}

enum LoginResult { ok, unknownUser, badPassword, inactive }

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._db) : super(const AuthState(null));
  final AppDatabase _db;

  Future<LoginResult> login(String login, String password) async {
    final query = _db.select(_db.users)
      ..where((u) => u.login.equals(login.trim()));
    final user = await query.getSingleOrNull();
    if (user == null) return LoginResult.unknownUser;
    if (!user.active) return LoginResult.inactive;
    final ok = BCrypt.checkpw(password, user.passwordHash);
    if (!ok) return LoginResult.badPassword;
    await (_db.update(_db.users)..where((u) => u.id.equals(user.id)))
        .write(UsersCompanion(lastLogin: Value(DateTime.now())));
    final refreshed = await (_db.select(_db.users)
          ..where((u) => u.id.equals(user.id)))
        .getSingle();
    state = AuthState(refreshed);
    return LoginResult.ok;
  }

  void logout() => state = const AuthState(null);
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(dbProvider)),
);

/// Permissions dérivées du rôle courant.
class Perms {
  final DbUserRole? role;
  const Perms(this.role);

  bool get canPos => role != null;
  bool get canViewCatalog => role != null;
  bool get canEditCatalog =>
      role == DbUserRole.admin || role == DbUserRole.superAdmin;
  bool get canStock =>
      role == DbUserRole.admin || role == DbUserRole.superAdmin;
  bool get canRooms => role != null;
  bool get canEditRooms =>
      role == DbUserRole.admin || role == DbUserRole.superAdmin;
  // Dashboard accessible à tous les rôles connectés (serveuses incluses).
  bool get canDashboard => role != null;
  bool get canHistory =>
      role == DbUserRole.admin || role == DbUserRole.superAdmin;
  bool get canManageServeurs =>
      role == DbUserRole.admin || role == DbUserRole.superAdmin;
  bool get canManageAdmins => role == DbUserRole.superAdmin;
  bool get canSettings => role == DbUserRole.superAdmin;
  // Réglage du taux de change : admin ET super admin.
  bool get canCurrency =>
      role == DbUserRole.admin || role == DbUserRole.superAdmin;
}

final permsProvider = Provider<Perms>((ref) {
  final auth = ref.watch(authProvider);
  return Perms(auth.user?.role);
});

/// Helpers d'affichage pour DbUserRole (label + couleur).
extension DbUserRoleUi on DbUserRole {
  String get label => switch (this) {
        DbUserRole.superAdmin => 'Super Admin',
        DbUserRole.admin => 'Admin',
        DbUserRole.serveur => 'Serveur',
      };
}
