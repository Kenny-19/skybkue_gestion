import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth.dart';
import '../../core/user_ui.dart';
import '../../data/seed.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/schema.dart';
import '../../services/accounts_service.dart';
import 'accounts_migration_dialog.dart';
import '../../shell/app_shell.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../core/temps.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permsProvider);
    final me = ref.watch(authProvider).user;
    final asyncUsers = ref.watch(usersStreamProvider);

    return asyncUsers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur BDD : $e')),
      data: (all) {
        final visible = all.where((u) {
          if (perms.canManageGerants) return true;
          return u.role != DbUserRole.superAdmin;
        }).toList()
          ..sort((a, b) => a.role.index.compareTo(b.role.index));

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                eyebrow: 'Comptes',
                title: 'Gestion des utilisateurs',
                subtitle:
                    '${visible.where((u) => u.active).length} actifs sur ${visible.length}',
                actions: [
                  // Reprise unique des comptes historiques vers
                  // Supabase — réservée au super admin, et masquée dès
                  // qu'il n'y a plus rien de local à reprendre.
                  if (perms.canManageGerants &&
                      all.any((u) => !u.isLocalDefault && u.syncedAt == null))
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                      onPressed: () => showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const AccountsMigrationDialog(),
                      ),
                      label: const Text('Reprise vers le serveur'),
                    ),
                  // Rafraîchit le cache local depuis Supabase, qui fait
                  // foi. Utile après une embauche/un départ saisi depuis
                  // un autre poste.
                  if (perms.canManageGerants)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.sync, size: 16),
                      onPressed: () => _sync(context, ref),
                      label: const Text('Synchroniser'),
                    ),
                  // Création : admin ET super admin. Le rôle "super admin"
                  // dans le formulaire n'est proposé qu'au super admin
                  // (voir _showAddDialog).
                  if (perms.canManageServeurs)
                    FilledButton.icon(
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      onPressed: () => _showAddDialog(context, ref, perms),
                      label: const Text('Nouvel utilisateur'),
                    ),
                ],
              ),
              // État du serveur AVANT tout clic : sans ça, on découvre
              // que rien ne marche en essayant de créer un compte.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                child: !perms.canManageGerants
                    ? const SizedBox.shrink()
                    : FutureBuilder<AccountsHealth>(
                        future: AccountsService.checkHealth(),
                        builder: (_, snap) {
                          final h = snap.data;
                          if (h == null || h.ok) return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.only(bottom: BsSpace.md),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: BsColors.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(BsRadius.sm),
                              border: Border.all(
                                  color:
                                      BsColors.danger.withValues(alpha: 0.3)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.cloud_off,
                                  size: 18, color: BsColors.danger),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(h.title,
                                        style: BsType.body(13,
                                            w: FontWeight.w700,
                                            color: BsColors.danger)),
                                    if (h.detail != null)
                                      Text(h.detail!,
                                          style: BsType.body(11,
                                              color: BsColors.slate)),
                                    Text(
                                        "Les comptes de secours continuent de "
                                        "fonctionner : l'application reste "
                                        "utilisable.",
                                        style: BsType.body(11,
                                            color: BsColors.slate)),
                                  ],
                                ),
                              ),
                            ]),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                child: _RoleLegend(),
              ),
              const SizedBox(height: BsSpace.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                child: Container(
                  decoration: BoxDecoration(
                    color: BsColors.paper,
                    borderRadius: BorderRadius.circular(BsRadius.md),
                    border: Border.all(color: BsColors.line),
                  ),
                  child: Column(
                    children: [
                      _headerRow(),
                      for (int i = 0; i < visible.length; i++)
                        _UserRow(
                          user: visible[i],
                          isMe: me?.id == visible[i].id,
                          canEdit: _canEdit(perms, visible[i]),
                          canDelete: _canDelete(perms, visible[i], me),
                          last: i == visible.length - 1,
                          onResetPassword: _canEdit(perms, visible[i])
                              ? () => _demanderNouveauMotDePasse(
                                  context, ref, visible[i])
                              : null,
                          onToggleActive: () => _run(
                            context,
                            ref,
                            (actor) => ref.read(usersRepoProvider).setActive(
                                  actor: actor,
                                  target: visible[i],
                                  active: !visible[i].active,
                                ),
                            success: visible[i].active
                                ? 'Compte désactivé sur le serveur.'
                                : 'Compte réactivé sur le serveur.',
                          ),
                          onDelete: () =>
                              _confirmDelete(context, ref, visible[i]),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: BsSpace.xxl),
            ],
          ),
        );
      },
    );
  }

  /// Contrôle l'activation / désactivation d'un compte depuis la liste.
  /// L'admin peut activer/désactiver les serveurs et les autres admins ;
  /// seuls les super admins sont intouchables sauf par un pair.
  ///
  /// ⚠️ Si un jour des actions d'ÉDITION (renommer, reset mot de passe)
  /// apparaissent dans l'UI, elles suivent la règle ci-dessous, qui
  /// reproduit celle du serveur.
  bool _canEdit(Perms p, User u) {
    // Exactement la règle que le serveur applique dans bs_set_password
    // et bs_set_active : seul un super admin touche à un compte de
    // niveau gérant ou super admin. Proposer davantage à l'écran
    // afficherait un bouton qui échoue une fois cliqué.
    //
    // Le gérant garde donc la main sur les serveuses et la réception —
    // y compris leur mot de passe, via le crayon.
    if (u.role == DbUserRole.superAdmin || u.role == DbUserRole.gerant) {
      return p.canManageGerants;
    }
    return p.canManageServeurs;
  }

  /// Suppression : super admin uniquement, jamais soi-même, jamais un
  /// autre super admin (les super admins sont propres à chaque machine).
  bool _canDelete(Perms p, User u, User? me) {
    if (!p.canDeleteAccounts) return false;
    if (me?.id == u.id) return false;
    if (u.role == DbUserRole.superAdmin) return false;
    return true;
  }

  Future<void> _confirmDelete(BuildContext ctx, WidgetRef ref, User u) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        backgroundColor: BsColors.paper,
        title: Text('Supprimer ${u.fullName} ?',
            style: BsType.display(18, w: FontWeight.w700)),
        content: Text(
          'Le compte @${u.login} sera supprimé sur ce poste ET sur '
          'tous les autres postes synchronisés.\n\nCette action est '
          'irréversible.',
          style: BsType.body(13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BsColors.danger),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !ctx.mounted) return;
    await _run(
      ctx,
      ref,
      (actor) => ref.read(usersRepoProvider).delete(actor: actor, target: u),
      success: 'Compte supprimé sur le serveur et sur tous les postes.',
    );
  }

  /// Rafraîchit la liste depuis Supabase et dit franchement ce qui s'est
  /// passé — y compris « pas de réseau », qui n'est pas une erreur mais
  /// une information dont la réception a besoin.
  static Future<void> _sync(BuildContext ctx, WidgetRef ref) async {
    try {
      final n = await ref.read(usersRepoProvider).syncFromCloud();
      if (ctx.mounted) {
        _snack(ctx, '$n compte(s) synchronisé(s) depuis le serveur.', ok: true);
      }
    } on AccountException catch (e) {
      if (ctx.mounted) _snack(ctx, e.message, ok: false);
    } catch (e) {
      if (ctx.mounted) {
        _snack(ctx, 'Échec de la synchronisation : $e', ok: false);
      }
    }
  }

  /// Exécute une opération d'administration de compte.
  ///
  /// Centralise les trois choses qui manquaient : vérifier qu'on a bien
  /// les identifiants de la session, afficher l'échec tel que le serveur
  /// l'explique (au lieu d'un « Identifiant déjà pris » attrape-tout),
  /// et distinguer une panne réseau d'un refus métier.
  /// Boîte de changement du mot de passe d'un employé.
  ///
  /// Propose le code provisoire par défaut : c'est le cas courant — un
  /// employé qui a oublié son code. L'application lui rappellera d'en
  /// choisir un autre à sa prochaine connexion.
  static Future<void> _demanderNouveauMotDePasse(
      BuildContext context, WidgetRef ref, User cible) async {
    final champ = TextEditingController(text: kMotDePasseProvisoire);
    final nouveau = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: BsColors.paper,
        title: Text('Mot de passe de ${cible.fullName}',
            style: BsType.display(18, w: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "L'employé pourra le changer lui-même ensuite. "
                "Laisse $kMotDePasseProvisoire pour lui donner le code "
                "provisoire habituel.",
                style: BsType.body(13, color: BsColors.slate)),
            const SizedBox(height: BsSpace.md),
            TextField(
              controller: champ,
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: 'Nouveau mot de passe'),
              onSubmitted: (v) => Navigator.of(dctx).pop(v),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.of(dctx).pop(champ.text),
            child: const Text('Changer'),
          ),
        ],
      ),
    );
    champ.dispose();
    if (nouveau == null || nouveau.trim().length < 4) return;
    if (!context.mounted) return;

    await _run(
      context,
      ref,
      (actor) => ref.read(usersRepoProvider).resetPassword(
            actor: actor,
            target: cible,
            newPassword: nouveau,
          ),
      success: nouveau == kMotDePasseProvisoire
          ? 'Mot de passe remis à $kMotDePasseProvisoire. '
              'Préviens ${cible.fullName}.'
          : 'Mot de passe changé.',
    );
  }

  static Future<bool> _run(
    BuildContext ctx,
    WidgetRef ref,
    Future<void> Function(({String login, String password}) actor) action, {
    required String success,
  }) async {
    final actor = ref.read(authProvider.notifier).actorCredentials;
    if (actor == null) {
      _snack(
          ctx,
          'Reconnecte-toi : la session ne permet pas de gérer '
          'les comptes.',
          ok: false);
      return false;
    }
    try {
      await action(actor);
      if (ctx.mounted) _snack(ctx, success, ok: true);
      return true;
    } on AccountException catch (e) {
      if (ctx.mounted) {
        _snack(
            ctx,
            e.isRetryable
                ? "${e.message} Rien n'a été modifié — réessaie "
                    "une fois la connexion revenue."
                : e.message,
            ok: false);
      }
      return false;
    } catch (e) {
      if (ctx.mounted) _snack(ctx, 'Échec inattendu : $e', ok: false);
      return false;
    }
  }

  static void _snack(BuildContext ctx, String msg, {required bool ok}) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      backgroundColor: ok ? BsColors.success : BsColors.danger,
      duration: Duration(seconds: ok ? 3 : 6),
      content: Text(msg,
          style: BsType.body(13, w: FontWeight.w600, color: Colors.white)),
    ));
  }

  Widget _headerRow() => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: BsSpace.lg, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: BsColors.line)),
        ),
        child: Row(children: [
          Expanded(
              flex: 4, child: Text('UTILISATEUR', style: BsType.eyebrow())),
          Expanded(
              flex: 2, child: Text('IDENTIFIANT', style: BsType.eyebrow())),
          Expanded(flex: 2, child: Text('RÔLE', style: BsType.eyebrow())),
          Expanded(
              flex: 2,
              child: Text('DERNIÈRE CONNEXION', style: BsType.eyebrow())),
          Expanded(flex: 2, child: Text('STATUT', style: BsType.eyebrow())),
          const SizedBox(width: 100),
        ]),
      );

  void _showAddDialog(BuildContext ctx, WidgetRef ref, Perms perms) {
    final fullName = TextEditingController();
    final login = TextEditingController();
    final pwd = TextEditingController();
    DbUserRole role = DbUserRole.serveur;
    String? err;
    bool busy = false;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (context, setSt) {
        return Dialog(
          backgroundColor: BsColors.paper,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BsRadius.md)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('NOUVEL UTILISATEUR', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  Text('Créer un compte',
                      style: BsType.display(24, w: FontWeight.w700)),
                  const SizedBox(height: 20),
                  _field('Nom complet', 'ex. Sarah Ilunga', fullName),
                  const SizedBox(height: 12),
                  _field('Identifiant', 'ex. sarah', login),
                  const SizedBox(height: 12),
                  _field('Mot de passe provisoire', '••••••••', pwd,
                      obscure: true),
                  const SizedBox(height: 12),
                  Text('RÔLE', style: BsType.eyebrow()),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    for (final r in DbUserRole.values)
                      if (r != DbUserRole.superAdmin || perms.canManageGerants)
                        GestureDetector(
                          onTap: () => setSt(() => role = r),
                          child: _RoleChip(role: r, selected: r == role),
                        ),
                  ]),
                  if (err != null) ...[
                    const SizedBox(height: 12),
                    Text(err!, style: BsType.body(12, color: BsColors.danger)),
                  ],
                  const SizedBox(height: 24),
                  Row(children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (fullName.text.trim().isEmpty ||
                                  login.text.trim().isEmpty ||
                                  pwd.text.isEmpty) {
                                setSt(
                                    () => err = 'Tous les champs sont requis');
                                return;
                              }
                              final actor = ref
                                  .read(authProvider.notifier)
                                  .actorCredentials;
                              if (actor == null) {
                                setSt(() => err =
                                    'Reconnecte-toi : la session ne permet pas '
                                        'de créer un compte.');
                                return;
                              }
                              setSt(() {
                                busy = true;
                                err = null;
                              });
                              try {
                                await ref.read(usersRepoProvider).create(
                                      actor: actor,
                                      fullName: fullName.text.trim(),
                                      login: login.text.trim(),
                                      password: pwd.text,
                                      role: role,
                                    );
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              } on AccountException catch (e) {
                                setSt(() {
                                  busy = false;
                                  err = e.message;
                                });
                              } catch (e) {
                                setSt(() {
                                  busy = false;
                                  err = 'Échec inattendu : $e';
                                });
                              }
                            },
                      child: Text(busy
                          ? 'Création sur le serveur…'
                          : 'Créer le compte'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _field(String label, String hint, TextEditingController c,
          {bool obscure = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: BsType.eyebrow()),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            obscureText: obscure,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      );
}

class _RoleLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: DbUserRole.values.map((r) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: r.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(BsRadius.sm),
            border: Border.all(color: r.color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: r.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(r.label,
                  style: BsType.body(11, w: FontWeight.w700, color: r.color)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final DbUserRole role;
  final bool selected;
  const _RoleChip({required this.role, required this.selected});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? role.color : Colors.transparent,
        border: Border.all(color: role.color),
        borderRadius: BorderRadius.circular(BsRadius.sm),
      ),
      child: Text(role.label,
          style: BsType.body(12,
              w: FontWeight.w700, color: selected ? Colors.white : role.color)),
    );
  }
}

/// Petite pastille de statut à côté du nom.
Widget _tag(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child:
          Text(label, style: BsType.body(9, w: FontWeight.w700, color: color)),
    );

class _UserRow extends StatelessWidget {
  final User user;
  final bool isMe;
  final bool canEdit;
  final bool canDelete;
  final bool last;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  /// Réinitialise le mot de passe de cet employé. Null quand l'acteur
  /// n'en a pas le droit sur CE compte.
  final VoidCallback? onResetPassword;
  const _UserRow({
    required this.user,
    required this.isMe,
    required this.canEdit,
    required this.canDelete,
    required this.last,
    required this.onToggleActive,
    required this.onDelete,
    this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    final lastLogin = user.lastLogin == null ? '—' : _relative(user.lastLogin!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BsSpace.lg, vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: BsColors.line)),
      ),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: user.role.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(user.initials,
                  style: BsType.body(12,
                      w: FontWeight.w700, color: user.role.color)),
            ),
            const SizedBox(width: 12),
            // Expanded + ellipses : sans ça, un nom long comme « Serveuse
            // (compte de secours) » plus sa pastille débordait sur la
            // colonne Identifiant.
            Expanded(
                child: Padding(
              padding: const EdgeInsets.only(right: BsSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(user.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BsType.body(13, w: FontWeight.w600)),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      _tag('vous', BsColors.sunrise),
                    ],
                    // D'où vient ce compte, et peut-il se connecter sans
                    // Internet ? C'est la première question qu'on se pose
                    // quand quelqu'un « n'arrive pas à se connecter ».
                    if (user.isLocalDefault) ...[
                      const SizedBox(width: 6),
                      _tag('secours · local', BsColors.slate),
                    ] else if (!isUsableHash(user.passwordHash)) ...[
                      const SizedBox(width: 6),
                      _tag('jamais connecté ici', BsColors.danger),
                    ],
                  ]),
                  Text(
                      user.isLocalDefault
                          ? 'Compte de secours — ne quitte pas ce poste'
                          : 'Créé le ${DateFormat("d MMM y", 'fr_FR').format(aLubumbashi(user.createdAt))}'
                              '${user.syncedAt == null ? "" : " · synchronisé ${_relative(user.syncedAt!)}"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BsType.body(11, color: BsColors.slate)),
                ],
              ),
            )),
          ]),
        ),
        Expanded(
          flex: 2,
          child: Text('@${user.login}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BsType.mono(12, color: BsColors.slate)),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _RoleTag(role: user.role),
          ),
        ),
        Expanded(
          flex: 2,
          child: Row(children: [
            Flexible(
              child: Text(lastLogin,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BsType.body(12, color: BsColors.slate)),
            ),
            // Le mot de passe lui-même ne peut PAS être affiché : il
            // n'est stocké nulle part en clair, seulement en empreinte
            // bcrypt, qui est à sens unique. Ce qu'un gérant a vraiment
            // besoin de savoir, c'est qui n'a pas encore changé le code
            // provisoire — cette information-là est sûre et utile.
            if (user.mustChangePassword) ...[
              const SizedBox(width: BsSpace.sm),
              Tooltip(
                message: 'Ce compte utilise encore le code provisoire '
                    '$kMotDePasseProvisoire',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: BsColors.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(BsRadius.sm),
                    border: Border.all(
                        color: BsColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Text('code $kMotDePasseProvisoire',
                      style: BsType.mono(10,
                          w: FontWeight.w700, color: BsColors.warning)),
                ),
              ),
            ],
          ]),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (user.active ? BsColors.success : BsColors.slate)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(user.active ? 'Actif' : 'Désactivé',
                  style: BsType.body(11,
                      w: FontWeight.w700,
                      color: user.active ? BsColors.success : BsColors.slate)),
            ),
          ),
        ),
        SizedBox(
          width: 140,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Le crayon : changer le mot de passe de cet employé.
              // Premier de la rangée parce que c'est l'action la plus
              // demandée — un code oublié bloque quelqu'un tout de suite.
              if (onResetPassword != null)
                IconButton(
                  tooltip: 'Changer le mot de passe',
                  onPressed: onResetPassword,
                  color: BsColors.sky,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                ),
              IconButton(
                tooltip: user.active ? 'Désactiver' : 'Réactiver',
                onPressed: (canEdit && !isMe) ? onToggleActive : null,
                icon: Icon(
                    user.active ? Icons.block : Icons.check_circle_outline,
                    size: 16),
              ),
              if (canDelete)
                IconButton(
                  tooltip: 'Supprimer définitivement',
                  onPressed: onDelete,
                  color: BsColors.danger,
                  icon: const Icon(Icons.delete_outline, size: 16),
                ),
            ],
          ),
        ),
      ]),
    );
  }

  String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return DateFormat("d MMM y", 'fr_FR').format(aLubumbashi(d));
  }
}

class _RoleTag extends StatelessWidget {
  final DbUserRole role;
  const _RoleTag({required this.role});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: role.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: role.color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(role.label,
              style: BsType.body(11, w: FontWeight.w700, color: role.color)),
        ],
      ),
    );
  }
}
