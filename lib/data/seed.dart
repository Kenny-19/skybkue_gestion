import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart';

import 'database.dart';
import 'schema.dart';

/// Comptes de SECOURS créés à l'installation.
///
/// Ils vivent uniquement sur le poste : jamais poussés vers Supabase,
/// jamais supprimés par une synchronisation. Ils servent à ouvrir l'app
/// le jour de l'installation et à dépanner quand Internet est coupé —
/// les vrais comptes nominatifs sont créés dans Supabase.
///
/// ⚠️ Ces codes sont publics par nature (ils sont dans le code source et
/// connus de toute l'équipe). Ils ne donnent volontairement PAS le rôle
/// super admin : l'administration réelle passe par un compte Supabase.
class LocalDefaultAccount {
  final String login;
  final String password;
  final String fullName;
  final DbUserRole role;
  const LocalDefaultAccount(
      this.login, this.password, this.fullName, this.role);
}

/// Mot de passe posé sur tout compte créé par un administrateur.
///
/// Il est volontairement trivial : l'employé le reçoit oralement, et
/// l'application lui impose de le changer à sa première connexion. Le
/// couple « défaut connu + changement forcé » vaut mieux qu'un mot de
/// passe choisi par l'admin, qui resterait connu de lui indéfiniment.
const String kMotDePasseProvisoire = '0000';

const kLocalDefaultAccounts = <LocalDefaultAccount>[
  LocalDefaultAccount('reception', '0000', 'Réception (compte de secours)',
      DbUserRole.reception),
  LocalDefaultAccount(
      'serveuse', '2000', 'Serveuse (compte de secours)', DbUserRole.serveur),
  LocalDefaultAccount(
      'admin', '7000', 'Gérant (compte de secours)', DbUserRole.gerant),
];

/// Données de démarrage d'une base NEUVE : les comptes de secours, et
/// rien d'autre.
///
/// Il n'y a plus d'articles ni de chambres d'exemple. Ils servaient en
/// démonstration ; en production, ils faisaient du tort :
///   * un poste neuf pousse tout son catalogue au serveur au démarrage.
///     Les 12 articles fictifs (« Poisson du jour », « Salade mixte »…)
///     se retrouvaient dans le catalogue réel, avec des stocks inventés ;
///   * il poussait aussi ses 19 chambres « Standard à 60 000 FC », par
///     numéro — par-dessus le type et le tarif des vraies chambres.
///
/// Un poste neuf reçoit le vrai catalogue et les vraies chambres du
/// serveur dans les quinze secondes (MirrorPullService), ou d'une
/// sauvegarde au premier démarrage (RestoreOnBoot).
Future<void> seedInitialData(AppDatabase db) async {
  await db.batch((b) {
    for (final a in kLocalDefaultAccounts) {
      b.insert(
        db.users,
        UsersCompanion.insert(
          fullName: a.fullName,
          login: a.login,
          passwordHash: BCrypt.hashpw(a.password, BCrypt.gensalt()),
          role: a.role,
          isLocalDefault: const Value(true),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  });
}
