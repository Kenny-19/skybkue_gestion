import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth.dart';
import '../../core/user_ui.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/schema.dart';
import '../../shell/app_shell.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

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
          if (perms.canManageAdmins) return true;
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
                  FilledButton.icon(
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    onPressed: () => _showAddDialog(context, ref, perms),
                    label: const Text('Nouvel utilisateur'),
                  ),
                ],
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
                          last: i == visible.length - 1,
                          onToggleActive: () {
                            ref
                                .read(usersRepoProvider)
                                .setActive(visible[i].id, !visible[i].active);
                          },
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

  bool _canEdit(Perms p, User u) {
    if (u.role == DbUserRole.superAdmin) return p.canManageAdmins;
    if (u.role == DbUserRole.admin) return p.canManageAdmins;
    return p.canManageServeurs;
  }

  Widget _headerRow() => Container(
        padding: const EdgeInsets.symmetric(horizontal: BsSpace.lg, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: BsColors.line)),
        ),
        child: Row(children: [
          Expanded(flex: 4, child: Text('UTILISATEUR', style: BsType.eyebrow())),
          Expanded(flex: 2, child: Text('IDENTIFIANT', style: BsType.eyebrow())),
          Expanded(flex: 2, child: Text('RÔLE', style: BsType.eyebrow())),
          Expanded(flex: 2, child: Text('DERNIÈRE CONNEXION', style: BsType.eyebrow())),
          Expanded(flex: 2, child: Text('STATUT', style: BsType.eyebrow())),
          const SizedBox(width: 60),
        ]),
      );

  void _showAddDialog(BuildContext ctx, WidgetRef ref, Perms perms) {
    final fullName = TextEditingController();
    final login = TextEditingController();
    final pwd = TextEditingController();
    DbUserRole role = DbUserRole.serveur;
    String? err;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (context, setSt) {
        return Dialog(
          backgroundColor: BsColors.paper,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(BsRadius.md)),
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
                  _field('Mot de passe provisoire', '••••••••', pwd, obscure: true),
                  const SizedBox(height: 12),
                  Text('RÔLE', style: BsType.eyebrow()),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    for (final r in DbUserRole.values)
                      if (r != DbUserRole.superAdmin || perms.canManageAdmins)
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
                      onPressed: () async {
                        if (fullName.text.trim().isEmpty ||
                            login.text.trim().isEmpty ||
                            pwd.text.isEmpty) {
                          setSt(() => err = 'Tous les champs sont requis');
                          return;
                        }
                        try {
                          await ref.read(usersRepoProvider).create(
                                fullName: fullName.text.trim(),
                                login: login.text.trim(),
                                password: pwd.text,
                                role: role,
                              );
                          if (context.mounted) Navigator.of(context).pop();
                        } catch (e) {
                          setSt(() => err = 'Identifiant déjà pris');
                        }
                      },
                      child: const Text('Créer le compte'),
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
                  decoration: BoxDecoration(color: r.color, shape: BoxShape.circle)),
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

class _UserRow extends StatelessWidget {
  final User user;
  final bool isMe;
  final bool canEdit;
  final bool last;
  final VoidCallback onToggleActive;
  const _UserRow({
    required this.user,
    required this.isMe,
    required this.canEdit,
    required this.last,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final lastLogin = user.lastLogin == null ? '—' : _relative(user.lastLogin!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BsSpace.lg, vertical: 14),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: BsColors.line)),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(user.fullName,
                      style: BsType.body(13, w: FontWeight.w600)),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: BsColors.sunrise.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text('vous',
                          style: BsType.body(9,
                              w: FontWeight.w700, color: BsColors.sunrise)),
                    ),
                  ],
                ]),
                Text(
                    'Créé le ${DateFormat("d MMM y", 'fr_FR').format(user.createdAt)}',
                    style: BsType.body(11, color: BsColors.slate)),
              ],
            ),
          ]),
        ),
        Expanded(
          flex: 2,
          child: Text('@${user.login}',
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
          child: Text(lastLogin, style: BsType.body(12, color: BsColors.slate)),
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
          width: 60,
          child: IconButton(
            tooltip: user.active ? 'Désactiver' : 'Réactiver',
            onPressed: (canEdit && !isMe) ? onToggleActive : null,
            icon: Icon(user.active ? Icons.block : Icons.check_circle_outline, size: 16),
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
    return DateFormat("d MMM y", 'fr_FR').format(d);
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
              decoration: BoxDecoration(color: role.color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(role.label,
              style: BsType.body(11, w: FontWeight.w700, color: role.color)),
        ],
      ),
    );
  }
}
