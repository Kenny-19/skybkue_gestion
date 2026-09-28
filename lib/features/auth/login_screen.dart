import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth.dart';
import '../../core/user_ui.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/schema.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  User? _picked;
  final _pwd = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _offline = false;

  Future<void> _submit() async {
    final u = _picked;
    if (u == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await ref.read(authProvider.notifier).login(u.login, _pwd.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.isOk) {
      // Connexion tranchée de mémoire : on le signale, la liste des
      // comptes peut être en retard sur le serveur.
      setState(() => _offline = res.offline);
      context.go('/');
      return;
    }
    // Le message du serveur est toujours plus précis que le nôtre.
    setState(() => _error = res.message ?? _defaultMessage(res.result));
  }

  static String _defaultMessage(LoginResult r) => switch (r) {
        LoginResult.ok => '',
        LoginResult.unknownUser => "Ce compte n'est plus accessible.",
        LoginResult.inactive => 'Ce compte a été désactivé.',
        LoginResult.badPassword => 'Mot de passe incorrect.',
        LoginResult.lockedOut => "Trop d'essais. Réessaie plus tard.",
      };

  @override
  void dispose() {
    _pwd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncUsers = ref.watch(usersStreamProvider);

    return Scaffold(
      backgroundColor: BsColors.ink,
      body: Row(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: BsColors.ink),
                const _LogoWatermark(),
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                              color: BsColors.sunrise, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 12),
                        Text('Skyblue',
                            style: BsType.display(26,
                                w: FontWeight.w700, color: Colors.white)),
                      ]),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GUEST HOUSE · BY AFRINVEST',
                              style: BsType.eyebrow(color: BsColors.slateSoft)),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 460,
                            child: Text(
                              'La maison\ndans une seule\napp.',
                              style: BsType.display(60,
                                  w: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                              width: 80, height: 3, color: BsColors.sunrise),
                        ],
                      ),
                      _AdminSecretTrigger(
                        onTap: () => _showAdminDialog(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              color: BsColors.papyrus,
              padding: const EdgeInsets.all(56),
              child: Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: asyncUsers.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) =>
                          Text('Erreur : $e', style: BsType.body(12)),
                      data: (all) {
                        final users = all
                            .where((u) => u.role != DbUserRole.superAdmin)
                            .toList()
                          ..sort((a, b) => a.fullName.compareTo(b.fullName));
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('CONNEXION', style: BsType.eyebrow()),
                            const SizedBox(height: 10),
                            Text('Bienvenue',
                                style: BsType.display(36, w: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text(
                                'Choisis ton compte puis entre ton mot de passe.',
                                style: BsType.body(13, color: BsColors.slate)),
                            const SizedBox(height: 32),
                            Text('UTILISATEUR', style: BsType.eyebrow()),
                            const SizedBox(height: 6),
                            _UserDropdown(
                              users: users,
                              picked: _picked,
                              onPick: (u) {
                                setState(() {
                                  _picked = u;
                                  _pwd.clear();
                                  _error = null;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            Text('MOT DE PASSE', style: BsType.eyebrow()),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _pwd,
                              obscureText: true,
                              enabled: _picked != null && !_busy,
                              onSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                hintText: _picked == null
                                    ? 'Sélectionne d\'abord un compte'
                                    : '••••••••',
                              ),
                            ),
                            if (_offline && _error == null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color:
                                      BsColors.sunrise.withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(BsRadius.sm),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.cloud_off,
                                      size: 14, color: BsColors.sunrise),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                        'Connexion validée hors ligne : la '
                                        'liste des comptes peut être en '
                                        'retard sur le serveur.',
                                        style: BsType.body(11,
                                            w: FontWeight.w600,
                                            color: BsColors.sunrise)),
                                  ),
                                ]),
                              ),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color:
                                      BsColors.danger.withValues(alpha: 0.08),
                                  borderRadius:
                                      BorderRadius.circular(BsRadius.sm),
                                  border: Border.all(
                                      color: BsColors.danger
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.error_outline,
                                      size: 14, color: BsColors.danger),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_error!,
                                        style: BsType.body(12,
                                            w: FontWeight.w600,
                                            color: BsColors.danger)),
                                  ),
                                ]),
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 48,
                              child: FilledButton(
                                onPressed:
                                    (_picked == null || _busy) ? null : _submit,
                                child: _busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Text('Se connecter'),
                              ),
                            ),
                            if (users.isEmpty) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: BsColors.paper,
                                  borderRadius:
                                      BorderRadius.circular(BsRadius.sm),
                                  border: Border.all(color: BsColors.line),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('AUCUN COMPTE UTILISATEUR',
                                        style: BsType.eyebrow()),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Demande à l\'administrateur d\'ajouter un compte, ou connecte-toi en super admin.',
                                      style: BsType.body(11,
                                          color: BsColors.slate),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Accès super admin repensé : **PASSPHRASE UNIQUE**, aucun identifiant.
  ///
  /// - Champ mono unique (16 caractères ou plus recommandés)
  /// - Match sur n'importe quel compte super admin local actif
  /// - Rate-limit : 3 échecs = 60 s de blocage, puis 5 min au-delà
  /// - Aucune trace du login super admin dans l'UI publique
  void _showAdminDialog(BuildContext ctx) {
    final phrase = TextEditingController();
    bool busy = false;
    bool obscured = true;
    String? err;
    int lockLeft = 0;
    Timer? lockTicker;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (context, setSt) {
        void startLockTicker() {
          lockTicker?.cancel();
          lockTicker = Timer.periodic(const Duration(seconds: 1), (t) {
            setSt(() {
              lockLeft--;
              if (lockLeft <= 0) {
                lockLeft = 0;
                t.cancel();
                err = null;
              }
            });
          });
        }

        Future<void> submit() async {
          if (busy || lockLeft > 0) return;
          if (phrase.text.isEmpty) {
            setSt(() => err = 'Entre la passphrase.');
            return;
          }
          setSt(() {
            busy = true;
            err = null;
          });
          final res = await ref
              .read(authProvider.notifier)
              .loginSuperAdminByPassphrase(phrase.text);
          if (!context.mounted) return;
          switch (res.result) {
            case LoginResult.ok:
              Navigator.of(context).pop();
              context.go('/');
              return;
            case LoginResult.lockedOut:
              setSt(() {
                busy = false;
                lockLeft = res.lockoutSeconds;
                err = 'Trop d\'essais. Réessaie dans ${lockLeft}s.';
              });
              startLockTicker();
              return;
            case LoginResult.unknownUser:
              setSt(() {
                busy = false;
                err = 'Aucun super admin sur ce poste.';
              });
              return;
            case LoginResult.badPassword:
            case LoginResult.inactive:
              setSt(() {
                busy = false;
                err = 'Passphrase incorrecte.';
                phrase.clear();
              });
              return;
          }
        }

        return Dialog(
          backgroundColor: BsColors.ink,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BsRadius.md)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.shield_outlined,
                        size: 18, color: BsColors.sunrise),
                    const SizedBox(width: 8),
                    Text('ACCÈS TECHNIQUE',
                        style: BsType.eyebrow(color: BsColors.sunrise)),
                  ]),
                  const SizedBox(height: 6),
                  Text('Passphrase super admin',
                      style: BsType.display(20,
                          w: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(
                      'Une seule phrase, aucun identifiant. Le compte super admin est local à ce poste.',
                      style: BsType.body(11, color: BsColors.slateSoft)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: phrase,
                    autofocus: true,
                    enabled: !busy && lockLeft == 0,
                    obscureText: obscured,
                    onSubmitted: (_) => submit(),
                    style: BsType.body(14, color: BsColors.ink),
                    decoration: InputDecoration(
                      hintText: '••••••••••••••••',
                      hintStyle: BsType.body(14, color: BsColors.slateSoft),
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscured
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18),
                        onPressed: () => setSt(() => obscured = !obscured),
                      ),
                    ),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Icon(
                          lockLeft > 0 ? Icons.lock_clock : Icons.error_outline,
                          size: 14,
                          color: BsColors.danger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(err!,
                            style: BsType.body(12,
                                w: FontWeight.w600, color: BsColors.danger)),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 20),
                  Row(children: [
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              lockTicker?.cancel();
                              Navigator.of(context).pop();
                            },
                      child: Text('Annuler',
                          style: BsType.body(12, color: BsColors.slateSoft)),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      icon: const Icon(Icons.key, size: 16),
                      onPressed: (busy || lockLeft > 0) ? null : submit,
                      style: FilledButton.styleFrom(
                          backgroundColor: BsColors.sunrise,
                          foregroundColor: BsColors.ink),
                      label: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: BsColors.ink))
                          : Text(lockLeft > 0
                              ? 'Bloqué (${lockLeft}s)'
                              : 'Déverrouiller'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      }),
    ).then((_) {
      // Sécurité : au cas où le dialog se ferme sans passer par Annuler.
      lockTicker?.cancel();
    });
  }
}

/// Logo Skyblue discret en filigrane, occupant tout le panneau gauche.
class _LogoWatermark extends StatelessWidget {
  const _LogoWatermark();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final side = c.maxWidth * 0.9;
      return Center(
        child: Opacity(
          opacity: 0.08,
          child: Image.asset(
            'assets/images/logo.png',
            width: side,
            height: side,
            fit: BoxFit.contain,
            color: Colors.white,
            colorBlendMode: BlendMode.srcIn,
            errorBuilder: (_, __, ___) => Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Sky',
                    style: BsType.display(180,
                        w: FontWeight.w800, color: Colors.white)),
                Text('blue',
                    style: BsType.display(180,
                        w: FontWeight.w300, color: Colors.white)),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Ligne discrète "© Skyblue Guest House — v0.1" en bas à gauche, cliquable pour
/// ouvrir la connexion super admin.
class _AdminSecretTrigger extends StatefulWidget {
  final VoidCallback onTap;
  const _AdminSecretTrigger({required this.onTap});
  @override
  State<_AdminSecretTrigger> createState() => _AdminSecretTriggerState();
}

class _AdminSecretTriggerState extends State<_AdminSecretTrigger> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: BsType.body(11,
              color: _hover ? BsColors.sunrise : BsColors.slateSoft),
          child: const Text('© Skyblue Guest House — v0.1'),
        ),
      ),
    );
  }
}

/// Liste des comptes toujours visible + recherche + scroll natif.
///
/// L'ancienne implémentation utilisait un DropdownButtonFormField dont
/// le menu se retrouvait tronqué sur Windows quand il y avait beaucoup
/// d'utilisateurs — certains devenaient invisibles et ne pouvaient plus
/// se connecter. Cette version affiche tous les comptes dans une liste
/// scrollable inline, avec une barre de recherche pour retrouver
/// rapidement le sien.
class _UserDropdown extends StatefulWidget {
  final List<User> users;
  final User? picked;
  final ValueChanged<User> onPick;
  const _UserDropdown({
    required this.users,
    required this.picked,
    required this.onPick,
  });

  @override
  State<_UserDropdown> createState() => _UserDropdownState();
}

class _UserDropdownState extends State<_UserDropdown> {
  final _searchCtrl = TextEditingController();
  String _q = '';
  // null = tous les rôles ; sinon on n'affiche que ce rôle-là.
  DbUserRole? _filterRole;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.users.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BsColors.paper,
          borderRadius: BorderRadius.circular(BsRadius.sm),
          border: Border.all(color: BsColors.line),
        ),
        child: Text('Aucun compte disponible',
            style: BsType.body(12, color: BsColors.slate)),
      );
    }
    Iterable<User> filteredIt = widget.users;
    if (_filterRole != null) {
      filteredIt = filteredIt.where((u) => u.role == _filterRole);
    }
    if (_q.isNotEmpty) {
      filteredIt = filteredIt.where((u) =>
          u.fullName.toLowerCase().contains(_q) ||
          u.login.toLowerCase().contains(_q));
    }
    final filtered = filteredIt.toList()
      // Tri secondaire : par rôle puis par nom, pour une lecture stable.
      ..sort((a, b) {
        final byRole = a.role.index.compareTo(b.role.index);
        if (byRole != 0) return byRole;
        return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      });

    // Compteurs par rôle pour les chips (sur TOUS les users, indépendant
    // du filtre courant — le nombre à côté est un guide de sélection).
    final roleCounts = <DbUserRole, int>{
      for (final r in DbUserRole.values) r: 0
    };
    for (final u in widget.users) {
      roleCounts[u.role] = (roleCounts[u.role] ?? 0) + 1;
    }
    // On affiche uniquement les rôles présents dans la liste visible
    // du login (les super admins ne sont jamais montrés ici).
    final availableRoles = roleCounts.entries
        .where((e) => e.value > 0 && e.key != DbUserRole.superAdmin)
        .map((e) => e.key)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filtre par rôle — chips cliquables
        if (availableRoles.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _RoleChipFilter(
                  label: 'Tous',
                  count: widget.users.length,
                  selected: _filterRole == null,
                  color: BsColors.slate,
                  onTap: () => setState(() => _filterRole = null),
                ),
                for (final r in availableRoles)
                  _RoleChipFilter(
                    label: r.label,
                    count: roleCounts[r]!,
                    selected: _filterRole == r,
                    color: r.color,
                    onTap: () => setState(() => _filterRole = r),
                  ),
              ],
            ),
          ),
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Rechercher (nom ou identifiant)',
            // Une icône, pas un emoji dans le texte : elle se colore
            // avec le thème et ne dépend pas de la police système.
            prefixIcon: const Icon(Icons.search, size: 18),
            hintStyle: BsType.body(12, color: BsColors.slateSoft),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          // Hauteur bornée + scroll → aucun compte ne peut être caché.
          constraints: const BoxConstraints(minHeight: 180, maxHeight: 320),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: BsColors.line),
            borderRadius: BorderRadius.circular(BsRadius.sm),
          ),
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Aucun résultat pour « $_q »',
                        style: BsType.body(11, color: BsColors.slate)),
                  ),
                )
              : Scrollbar(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final u = filtered[i];
                      final chosen = widget.picked?.id == u.id;
                      return InkWell(
                        onTap: () => widget.onPick(u),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: chosen
                                ? BsColors.sunrise.withValues(alpha: 0.10)
                                : null,
                            border: Border(
                              bottom: i == filtered.length - 1
                                  ? BorderSide.none
                                  : const BorderSide(color: BsColors.line),
                              left: chosen
                                  ? const BorderSide(
                                      color: BsColors.sunrise, width: 3)
                                  : BorderSide.none,
                            ),
                          ),
                          child: Row(children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: u.role.color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(u.initials,
                                  style: BsType.body(11,
                                      w: FontWeight.w700, color: u.role.color)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(u.fullName,
                                      style:
                                          BsType.body(13, w: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis),
                                  Text(
                                      '${u.role.label} · @${u.login}'
                                      '${u.active ? "" : " · désactivé"}',
                                      style: BsType.body(10,
                                          color: BsColors.slate)),
                                ],
                              ),
                            ),
                            if (!u.active)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: BsColors.slate.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text('DÉSACTIVÉ',
                                    style: BsType.body(9,
                                        w: FontWeight.w700,
                                        color: BsColors.slate)),
                              ),
                            if (chosen) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.check_circle,
                                  size: 16, color: BsColors.sunrise),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${widget.users.length} compte(s) disponible(s)',
              style: BsType.body(10, color: BsColors.slateSoft)),
        ),
      ],
    );
  }
}

/// Chip cliquable pour filtrer la liste des comptes par rôle.
/// Compact, coloré par rôle (badge point + label + compteur).
class _RoleChipFilter extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _RoleChipFilter({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BsRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(BsRadius.sm),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: selected ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: BsType.body(11,
                    w: FontWeight.w700,
                    color: selected ? Colors.white : color)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.25)
                    : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('$count',
                  style: BsType.mono(9,
                      w: FontWeight.w800,
                      color: selected ? Colors.white : color)),
            ),
          ],
        ),
      ),
    );
  }
}
