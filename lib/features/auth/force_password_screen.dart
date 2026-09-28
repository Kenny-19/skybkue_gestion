import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth.dart';
import '../../core/user_error.dart';
import '../../data/providers.dart';
import '../../data/seed.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/bs_widgets.dart';

/// Changement du mot de passe provisoire.
///
/// Tout compte créé par un administrateur reçoit `0000`, communiqué
/// oralement à l'employé. L'application le RAPPELLE sans enfermer :
/// décision produit, parce que toute l'équipe est prévenue et qu'un
/// blocage en plein service coûterait plus qu'il ne protège.
///
/// Le rappel reste visible tant que le code provisoire tient.
class ForcePasswordScreen extends ConsumerStatefulWidget {
  const ForcePasswordScreen({super.key});

  @override
  ConsumerState<ForcePasswordScreen> createState() =>
      _ForcePasswordScreenState();
}

class _ForcePasswordScreenState extends ConsumerState<ForcePasswordScreen> {
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _erreur;

  @override
  void dispose() {
    _nouveau.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    final nouveau = _nouveau.text;
    if (nouveau.length < 4) {
      setState(() => _erreur = 'Choisis au moins 4 caractères.');
      return;
    }
    if (nouveau == kMotDePasseProvisoire) {
      setState(
          () => _erreur = 'Choisis autre chose que $kMotDePasseProvisoire : '
              'tout le monde le connaît.');
      return;
    }
    if (nouveau != _confirmation.text) {
      setState(() => _erreur = 'Les deux saisies ne correspondent pas.');
      return;
    }

    setState(() {
      _busy = true;
      _erreur = null;
    });
    try {
      final auth = ref.read(authProvider.notifier);
      final me = ref.read(authProvider).user!;
      await ref.read(usersRepoProvider).changeOwnPassword(
            actor: auth.actorCredentials!,
            me: me,
            newPassword: nouveau,
          );
      // La session porte l'ancien mot de passe : on la rafraîchit, sinon
      // la prochaine opération серveur serait refusée.
      await auth.refreshSession(nouveau);
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _erreur = handleError(e, st, context: 'forcePassword').message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: BsColors.ink,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: BsCard(
              padding: const EdgeInsets.all(BsSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('PREMIÈRE CONNEXION',
                      style: BsType.eyebrow(color: BsColors.sky)),
                  const SizedBox(height: BsSpace.sm),
                  Text('Choisis ton mot de passe',
                      style: BsType.display(24, w: FontWeight.w700)),
                  const SizedBox(height: BsSpace.sm),
                  Text(
                      me == null
                          ? ''
                          : 'Bonjour ${me.fullName}. Ton compte a été créé '
                              'avec le code provisoire $kMotDePasseProvisoire, '
                              'que tout le monde connaît. Choisis-en un autre '
                              'pour continuer.',
                      style: BsType.body(14, color: BsColors.slate)),
                  const SizedBox(height: BsSpace.lg),
                  TextField(
                    controller: _nouveau,
                    obscureText: true,
                    autofocus: true,
                    decoration: const InputDecoration(
                        labelText: 'Nouveau mot de passe'),
                  ),
                  const SizedBox(height: BsSpace.smd),
                  TextField(
                    controller: _confirmation,
                    obscureText: true,
                    onSubmitted: (_) => _busy ? null : _valider(),
                    decoration: const InputDecoration(labelText: 'Confirme-le'),
                  ),
                  if (_erreur != null) ...[
                    const SizedBox(height: BsSpace.smd),
                    Text(_erreur!,
                        style: BsType.body(13,
                            w: FontWeight.w600, color: BsColors.danger)),
                  ],
                  const SizedBox(height: BsSpace.lg),
                  SizedBox(
                    height: BsControl.primary,
                    child: FilledButton(
                      onPressed: _busy ? null : _valider,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Enregistrer et continuer'),
                    ),
                  ),
                  const SizedBox(height: BsSpace.sm),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Plus tard'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
