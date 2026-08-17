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

  Future<void> _submit() async {
    final u = _picked;
    if (u == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await ref
        .read(authProvider.notifier)
        .login(u.login, _pwd.text);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (res) {
      case LoginResult.ok:
        context.go('/');
        break;
      case LoginResult.unknownUser:
      case LoginResult.inactive:
        setState(() => _error = 'Ce compte n\'est plus accessible.');
        break;
      case LoginResult.badPassword:
        setState(() => _error = 'Mot de passe incorrect.');
        break;
    }
  }

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
                          Container(width: 80, height: 3, color: BsColors.sunrise),
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
                          ..sort(
                              (a, b) => a.fullName.compareTo(b.fullName));
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
                                style:
                                    BsType.body(13, color: BsColors.slate)),
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
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: BsColors.danger.withValues(alpha: 0.08),
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
                                onPressed: (_picked == null || _busy)
                                    ? null
                                    : _submit,
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
                                  border:
                                      Border.all(color: BsColors.line),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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

  void _showAdminDialog(BuildContext ctx) {
    final login = TextEditingController();
    final pwd = TextEditingController();
    bool busy = false;
    String? err;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (context, setSt) {
        Future<void> submit() async {
          if (busy) return;
          setSt(() {
            busy = true;
            err = null;
          });
          final res = await ref
              .read(authProvider.notifier)
              .login(login.text, pwd.text);
          if (!context.mounted) return;
          if (res == LoginResult.ok) {
            // Vérifier que c'est bien un super admin.
            final u = ref.read(authProvider).user;
            if (u?.role != DbUserRole.superAdmin) {
              ref.read(authProvider.notifier).logout();
              setSt(() {
                busy = false;
                err = 'Ce compte n\'a pas les droits super administrateur.';
              });
              return;
            }
            Navigator.of(context).pop();
            context.go('/');
            return;
          }
          setSt(() {
            busy = false;
            err = switch (res) {
              LoginResult.unknownUser => 'Identifiant inconnu.',
              LoginResult.badPassword => 'Mot de passe incorrect.',
              LoginResult.inactive => 'Ce compte est désactivé.',
              LoginResult.ok => null,
            };
          });
        }

        return Dialog(
          backgroundColor: BsColors.ink,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BsRadius.md)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.admin_panel_settings,
                        size: 18, color: BsColors.sunrise),
                    const SizedBox(width: 8),
                    Text('SUPER ADMINISTRATEUR',
                        style: BsType.eyebrow(color: BsColors.sunrise)),
                  ]),
                  const SizedBox(height: 6),
                  Text('Accès technique',
                      style: BsType.display(20,
                          w: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 20),
                  Text('IDENTIFIANT',
                      style: BsType.eyebrow(color: BsColors.slateSoft)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: login,
                    autofocus: true,
                    enabled: !busy,
                    style: BsType.body(14, color: Colors.white),
                    decoration: const InputDecoration(hintText: 'ex. kenny'),
                  ),
                  const SizedBox(height: 12),
                  Text('MOT DE PASSE',
                      style: BsType.eyebrow(color: BsColors.slateSoft)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: pwd,
                    obscureText: true,
                    enabled: !busy,
                    onSubmitted: (_) => submit(),
                    style: BsType.body(14, color: Colors.white),
                    decoration: const InputDecoration(hintText: '••••••••'),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 10),
                    Text(err!,
                        style: BsType.body(12, color: BsColors.danger)),
                  ],
                  const SizedBox(height: 20),
                  Row(children: [
                    TextButton(
                      onPressed:
                          busy ? null : () => Navigator.of(context).pop(),
                      child: Text('Annuler',
                          style: BsType.body(12, color: BsColors.slateSoft)),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      style: FilledButton.styleFrom(
                          backgroundColor: BsColors.sunrise,
                          foregroundColor: BsColors.ink),
                      child: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: BsColors.ink))
                          : const Text('Accéder'),
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

class _UserDropdown extends StatelessWidget {
  final List<User> users;
  final User? picked;
  final ValueChanged<User> onPick;
  const _UserDropdown({
    required this.users,
    required this.picked,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
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
    return DropdownButtonFormField<int>(
      initialValue: picked?.id,
      isExpanded: true,
      itemHeight: 56, // deux lignes + padding
      decoration: const InputDecoration(),
      hint: Text('— Sélectionner un compte —',
          style: BsType.body(13, color: BsColors.slate)),
      // Version compacte affichée dans le champ (1 ligne).
      selectedItemBuilder: (_) => users
          .map((u) => Row(children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: u.role.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(u.initials,
                      style: BsType.body(9,
                          w: FontWeight.w700, color: u.role.color)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${u.fullName}  ·  ${u.role.label}',
                    style: BsType.body(13, w: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]))
          .toList(),
      // Version enrichie dans le menu déroulant (2 lignes).
      items: users.map((u) {
        return DropdownMenuItem<int>(
          value: u.id,
          child: Row(children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: u.role.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(u.initials,
                  style: BsType.body(10,
                      w: FontWeight.w700, color: u.role.color)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(u.fullName,
                      style: BsType.body(12, w: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  Text('${u.role.label} · ${u.active ? "actif" : "désactivé"}',
                      style: BsType.body(10, color: BsColors.slate)),
                ],
              ),
            ),
            if (!u.active)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BsColors.slate.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text('DÉSACTIVÉ',
                    style: BsType.body(9,
                        w: FontWeight.w700, color: BsColors.slate)),
              ),
          ]),
        );
      }).toList(),
      onChanged: (id) {
        if (id == null) return;
        onPick(users.firstWhere((u) => u.id == id));
      },
    );
  }
}
