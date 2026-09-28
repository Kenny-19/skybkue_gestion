import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth.dart';
import '../../services/accounts_migration.dart';
import '../../services/accounts_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Reprise des comptes locaux vers Supabase — opération **unique**, à
/// lancer depuis le poste dont la liste de comptes fait référence.
///
/// Déroulé en trois écrans dans la même boîte :
///   1. préparation (on interroge le serveur pour savoir ce qui existe) ;
///   2. prévisualisation : qui monte, qui est ignoré et pourquoi ;
///   3. rapport ligne par ligne.
///
/// Rien n'est envoyé avant que l'utilisateur ait vu la liste et cliqué.
class AccountsMigrationDialog extends ConsumerStatefulWidget {
  const AccountsMigrationDialog({super.key});

  @override
  ConsumerState<AccountsMigrationDialog> createState() =>
      _AccountsMigrationDialogState();
}

class _AccountsMigrationDialogState
    extends ConsumerState<AccountsMigrationDialog> {
  final _token = TextEditingController();
  List<MigrationCandidate>? _plan;
  MigrationReport? _report;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final plan = await AccountsMigration.prepare(ref.read(dbProvider));
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _busy = false;
      });
    } on AccountException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = 'Échec inattendu : $e';
      });
    }
  }

  Future<void> _run() async {
    final plan = _plan;
    if (plan == null) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    // Un super admin déjà connecté peut autoriser la reprise sans jeton.
    final me = ref.read(authProvider).user;
    final actor = (me != null && me.role.index == 0)
        ? ref.read(authProvider.notifier).actorCredentials
        : null;
    try {
      final report = await AccountsMigration.run(
        ref.read(dbProvider),
        plan,
        token: _token.text,
        actor: actor,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _busy = false;
      });
    } on AccountException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: BsColors.paper,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BsRadius.md)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('REPRISE DES COMPTES',
                  style: BsType.eyebrow(color: BsColors.sky)),
              const SizedBox(height: 6),
              Text(
                  _report == null
                      ? 'Envoyer les comptes de ce poste vers le serveur'
                      : 'Reprise terminée',
                  style: BsType.display(18, w: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                  _report != null
                      ? _report!.summary
                      : 'Les mots de passe actuels sont conservés : c\'est '
                          'le mot de passe chiffré qui est transmis, jamais '
                          'le mot de passe lui-même. À lancer depuis le '
                          'poste dont la liste de comptes est la bonne.',
                  style: BsType.body(11, color: BsColors.slateSoft)),
              const SizedBox(height: 16),
              Flexible(child: SingleChildScrollView(child: _body())),
              if (_err != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BsColors.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(BsRadius.sm),
                  ),
                  child: Text(_err!,
                      style: BsType.body(12,
                          w: FontWeight.w600, color: BsColors.danger)),
                ),
              ],
              const SizedBox(height: 16),
              _actions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_report != null) return _reportView(_report!);
    if (_busy && _plan == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final plan = _plan;
    if (plan == null) {
      return Text(
          'Impossible de préparer la reprise tant que le serveur est '
          'injoignable — on ne veut pas envoyer à l\'aveugle.',
          style: BsType.body(12, color: BsColors.slate));
    }

    final toImport = plan.where((c) => c.willImport).toList();
    final skipped = plan.where((c) => !c.willImport).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _jetonField(),
        const SizedBox(height: 16),
        _sectionTitle(
            '${toImport.length} compte(s) à reprendre', BsColors.success),
        if (toImport.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Rien à reprendre : tout est déjà sur le serveur.',
                style: BsType.body(12, color: BsColors.slate)),
          ),
        for (final c in toImport)
          _row(c.user.fullName, c.user.login, c.user.role.label, null),
        if (skipped.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionTitle('${skipped.length} ignoré(s)', BsColors.slate),
          for (final c in skipped)
            _row(c.user.fullName, c.user.login, c.user.role.label,
                c.skip!.label),
        ],
      ],
    );
  }

  Widget _jetonField() {
    final me = ref.read(authProvider).user;
    final isSuperAdmin = me != null && me.role.index == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('JETON DE REPRISE', style: BsType.eyebrow()),
        const SizedBox(height: 4),
        Text(
            isSuperAdmin
                ? 'Facultatif : ta session super admin suffit si ton compte '
                    'existe déjà sur le serveur. Sinon, génère un jeton dans '
                    'Supabase → SQL Editor :'
                : 'Génère-le dans Supabase → SQL Editor :',
            style: BsType.body(10, color: BsColors.slateSoft)),
        const SizedBox(height: 4),
        SelectableText('select public.bs_new_import_token();',
            style: BsType.body(11, w: FontWeight.w700, color: BsColors.sky)),
        const SizedBox(height: 6),
        TextField(
          controller: _token,
          decoration: const InputDecoration(
            hintText: 'Coller le jeton ici',
            isDense: true,
            prefixIcon: Icon(Icons.vpn_key_outlined, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _reportView(MigrationReport r) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!r.isCleanRun)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                  'Certains comptes n\'ont pas été repris. Corrige la cause '
                  'et relance : les comptes déjà repris seront simplement '
                  'signalés « déjà présent ».',
                  style: BsType.body(11,
                      w: FontWeight.w600, color: BsColors.danger)),
            ),
          for (final l in r.lines)
            _row(
              l.login,
              null,
              switch (l.outcome) {
                MigrationOutcome.imported => 'repris',
                MigrationOutcome.skipped => 'ignoré',
                MigrationOutcome.failed => 'échec',
              },
              l.detail,
              color: switch (l.outcome) {
                MigrationOutcome.imported => BsColors.success,
                MigrationOutcome.skipped => BsColors.slate,
                MigrationOutcome.failed => BsColors.danger,
              },
            ),
        ],
      );

  Widget _sectionTitle(String label, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label.toUpperCase(), style: BsType.eyebrow(color: color)),
      );

  Widget _row(String title, String? login, String tag, String? detail,
          {Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.circle, size: 7, color: color ?? BsColors.slateSoft),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(login == null ? title : '$title  ·  @$login',
                      style: BsType.body(12, w: FontWeight.w600)),
                  if (detail != null)
                    Text(detail,
                        style: BsType.body(10,
                            color: color ?? BsColors.slateSoft)),
                ],
              ),
            ),
            Text(tag,
                style: BsType.body(10,
                    w: FontWeight.w700, color: color ?? BsColors.slate)),
          ],
        ),
      );

  Widget _actions() {
    if (_report != null) {
      return Row(children: [
        const Spacer(),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Fermer'),
        ),
      ]);
    }
    final toImport = _plan?.where((c) => c.willImport).length ?? 0;
    return Row(children: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        child: const Text('Annuler'),
      ),
      const Spacer(),
      FilledButton.icon(
        icon: _busy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.cloud_upload_outlined, size: 16),
        style: FilledButton.styleFrom(backgroundColor: BsColors.sky),
        onPressed: (_busy || toImport == 0) ? null : _run,
        label: Text(toImport == 0
            ? 'Rien à reprendre'
            : 'Reprendre $toImport compte(s)'),
      ),
    ]);
  }
}
