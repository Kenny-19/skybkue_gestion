import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import '../../core/user_error.dart';
import '../../services/mirror_pull_service.dart';
import '../../core/app_version.dart';
import '../../core/auth.dart';
import '../../services/accounts_service.dart';
import '../../core/format.dart';
import '../../data/providers.dart';
import '../../services/auto_backup.dart';
import '../../services/backup_service.dart';
import '../../services/cloud_service.dart';
import '../../services/mirror_service.dart';
import '../../services/update_service.dart';
import '../../shell/app_shell.dart';
import '../../core/horloge.dart';
import '../../services/horloge_service.dart';
import '../../services/ventes_outbox.dart';
import '../../widgets/bs_widgets.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../core/temps.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider).user;
    final perms = ref.watch(permsProvider);
    final isSuper = perms.canSettings;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            eyebrow: 'Paramètres',
            title: 'Configuration',
            subtitle: 'Sauvegarde, mot de passe',
          ),
          BsPageBody(
            children: [
              // Version + verification manuelle de mise a jour —
              // accessible a TOUS les utilisateurs connectes.
              const _AppUpdateSection(),
              // Horloge du poste — avant tout le reste, parce qu'une
              // horloge fausse fausse TOUT le reste sans rien casser
              // visiblement.
              if (perms.canManageServeurs) const _HorlogeSection(),
              // Ventes pas encore en ligne. En tête, parce qu'une file
              // qui ne se vide pas doit se voir sans qu'on la cherche.
              if (perms.canManageServeurs) const _FileVentesSection(),
              _Section(
                title: 'Mon mot de passe',
                subtitle:
                    'Change-le régulièrement, surtout depuis le compte par défaut',
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.lock_outline, size: 16),
                  onPressed: me == null
                      ? null
                      : () => _showChangePassword(context, ref, me.id),
                  label: const Text('Changer mon mot de passe'),
                ),
              ),
              // Taux de change FC → USD — accessible admin + super admin.
              if (perms.canCurrency) const _CurrencySection(),
              // Récupération ORDINAIRE — gérant et super admin.
              //
              // Ne supprime rien : elle va chercher ce qui manque
              // (articles, chambres, clients, sociétés) et met à jour les
              // fiches. C'est le travail de la synchro automatique,
              // déclenché à la main quand on ne veut pas attendre.
              //
              // À ne pas confondre avec la restauration ci-dessous, qui
              // EFFACE. Les deux portaient le même nom, et c'est
              // exactement ce qui a conduit à la catastrophe de septembre.
              if (perms.canManageServeurs)
                const _Section(
                  title: 'Récupérer les données du cloud',
                  subtitle: "Va chercher les ventes, articles, chambres, "
                      "clients, sociétés et comptes des autres postes. Seul "
                      "ce qui manque est ajouté : rien n'est supprimé, "
                      "aucune vente de ce poste n'est touchée, le stock "
                      "reste intact.",
                  child: _PullNowButton(),
                ),
              // Récupération d'urgence — SUPER ADMIN SEUL.
              //
              // La garde était `canHistory`, qui vaut vrai pour TOUS les
              // rôles connectés : une serveuse pouvait donc écraser la
              // base locale du poste. C'est ce bouton qui a recréé les
              // comptes avec des mots de passe aléatoires en septembre.
              //
              // Ce n'est plus un outil de synchronisation : le catalogue,
              // les chambres, les clients et les sociétés se
              // rafraîchissent tout seuls toutes les 15 secondes. Il ne
              // reste qu'un secours, pour un poste dont la base est
              // perdue ou corrompue.
              //
              // Le gérant n'en a pas besoin : « Récupérer maintenant »
              // ramène les mêmes données, ventes comprises, sans rien
              // effacer.
              if (isSuper) ...[
                _Section(
                  title: 'Récupération d\'urgence (données miroir)',
                  subtitle:
                      'Retélécharge ventes, produits, chambres et comptes depuis Supabase et écrase les données locales. Les mots de passe existants sont préservés.',
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cloud_sync_outlined, size: 16),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BsColors.danger,
                      side: const BorderSide(color: BsColors.danger),
                    ),
                    onPressed: () => _confirmMirrorRestore(context, ref),
                    label: const Text('Récupérer depuis les données miroir'),
                  ),
                ),
              ],
              // Reset transactions pre-prod (super admin uniquement).
              if (isSuper) _ResetTransactionsSection(),
              // Sections réservées au Super Admin.
              if (isSuper) ...[
                _Section(
                  title: 'Sauvegarde de la base de données',
                  subtitle:
                      'Copie du fichier blue_sky.db — garde-la à l\'abri (clé USB, cloud)',
                  child: Wrap(spacing: 10, runSpacing: 10, children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.download, size: 16),
                      onPressed: () async {
                        final path = await BackupService.exportDatabase();
                        if (context.mounted && path != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Sauvegardé : $path')));
                        }
                      },
                      label: const Text('Exporter la BDD'),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.upload, size: 16),
                      onPressed: () async {
                        final ok = await _confirmImport(context);
                        if (!ok) return;
                        final path = await BackupService.importDatabase();
                        if (context.mounted && path != null) {
                          _showRestartDialog(context);
                        }
                      },
                      label: const Text('Restaurer une sauvegarde'),
                    ),
                  ]),
                ),
                const _CloudSection(),
                _Section(
                  title: 'Emplacement de la base',
                  subtitle:
                      'Dossier où le fichier de données est stocké sur ce PC',
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BsColors.papyrus,
                      borderRadius: BorderRadius.circular(BsRadius.sm),
                      border: Border.all(color: BsColors.line),
                    ),
                    child: Text('Documents/BlueSky/blue_sky.db',
                        style: BsType.mono(12, color: BsColors.slate)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: BsSpace.xxl),
        ],
      ),
    );
  }

  /// Dialogue de confirmation + exécution de la restauration miroir.
  Future<void> _confirmMirrorRestore(BuildContext ctx, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Récupérer depuis le miroir Supabase ?'),
        content: const Text(
            'Les ventes, produits, chambres et comptes de la BDD locale seront '
            'REMPLACÉS par ceux du miroir cloud. Les mots de passe locaux déjà '
            'connus sont préservés (les nouveaux comptes reçoivent un mot de '
            'passe temporaire, à réinitialiser).\n\n'
            'À utiliser après une perte de données locale. Continuer ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: BsColors.danger),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Récupérer')),
        ],
      ),
    );
    if (ok != true || !ctx.mounted) return;

    // Loader attaché au ROOT navigator (pas à celui de go_router) — sinon
    // les invalidations de providers plus bas déclenchent un rebuild qui
    // dispose le Navigator local pendant que le pop du loader est en cours,
    // et Flutter throw un `_debugLocked` assert. Root navigator = stable.
    showDialog(
      context: ctx,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await MirrorService.restoreFromMirror();

    // Ferme le loader du root nav en premier, AVANT toute invalidation.
    final rootNav = Navigator.of(ctx, rootNavigator: true);
    if (rootNav.canPop()) rootNav.pop();

    // Différer l'invalidation d'un frame → aucun rebuild ne peut se
    // superposer au pop du dialog qui vient d'être demandé.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ctx.mounted) return;
      ref.invalidate(articlesStreamProvider);
      ref.invalidate(roomsStreamProvider);
      ref.invalidate(recentSalesProvider);
      ref.invalidate(usersStreamProvider);
      ref.invalidate(metricsWeekProvider);
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(
            res.ok ? 'Récupération miroir OK — ${res.summary}' : res.message),
        duration: const Duration(seconds: 5),
      ));
    });
  }

  Future<bool> _confirmImport(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Restaurer une sauvegarde ?'),
        content: const Text(
            'La base actuelle sera remplacée par le fichier choisi. L\'app doit être redémarrée après. Continuer ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Restaurer')),
        ],
      ),
    );
    return ok ?? false;
  }

  void _showRestartDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Restauration effectuée'),
        content: const Text(
            'La base a été restaurée. Ferme et relance l\'application pour que les changements prennent effet.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Compris')),
        ],
      ),
    );
  }

  void _showChangePassword(BuildContext ctx, WidgetRef ref, int userId) {
    final pwd = TextEditingController();
    final confirm = TextEditingController();
    String? err;
    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (context, setSt) {
        return Dialog(
          backgroundColor: BsColors.paper,
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
                  Text('CHANGER LE MOT DE PASSE', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  Text('Nouveau mot de passe',
                      style: BsType.display(20, w: FontWeight.w700)),
                  const SizedBox(height: 20),
                  Text('NOUVEAU MOT DE PASSE', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: pwd,
                    obscureText: true,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: '••••••••'),
                  ),
                  const SizedBox(height: 12),
                  Text('CONFIRMATION', style: BsType.eyebrow()),
                  const SizedBox(height: 6),
                  TextField(
                    controller: confirm,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '••••••••'),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 10),
                    Text(err!, style: BsType.body(12, color: BsColors.danger)),
                  ],
                  const SizedBox(height: 20),
                  Row(children: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler')),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        if (pwd.text.length < 4) {
                          setSt(() => err = '4 caractères minimum');
                          return;
                        }
                        if (pwd.text != confirm.text) {
                          setSt(() => err = 'Les deux champs diffèrent');
                          return;
                        }
                        final notifier = ref.read(authProvider.notifier);
                        final me = ref.read(authProvider).user;
                        final actor = notifier.actorCredentials;
                        if (me == null || actor == null) {
                          setSt(() =>
                              err = 'Reconnecte-toi avant de changer ton mot '
                                  'de passe.');
                          return;
                        }
                        setSt(() => err = null);
                        try {
                          await ref.read(usersRepoProvider).changeOwnPassword(
                                actor: actor,
                                me: me,
                                newPassword: pwd.text,
                              );
                        } on AccountException catch (e) {
                          setSt(() => err = e.message);
                          return;
                        } catch (e) {
                          setSt(() => err = 'Échec inattendu : $e');
                          return;
                        }
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Mot de passe changé.')));
                        }
                      },
                      child: const Text('Enregistrer'),
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

class _CloudSection extends StatefulWidget {
  const _CloudSection();
  @override
  State<_CloudSection> createState() => _CloudSectionState();
}

class _CloudSectionState extends State<_CloudSection> {
  String _status = '…';
  bool _busy = false;
  DateTime? _lastBackup;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await CloudService.statusLabel();
    final last = await AutoBackup.lastBackup();
    if (mounted) {
      setState(() {
        _status = s;
        _lastBackup = last;
      });
    }
  }

  String get _lastBackupLabel {
    if (_lastBackup == null) return 'Aucune sauvegarde automatique encore';
    return 'Dernière sauvegarde : ${DateFormat("d MMM y 'à' HH:mm", 'fr_FR').format(aLubumbashi(_lastBackup!))}';
  }

  Color get _statusColor => switch (_status) {
        'En ligne' => BsColors.success,
        'Hors ligne' => BsColors.warning,
        _ => BsColors.slate,
      };

  @override
  Widget build(BuildContext context) {
    final configured = CloudService.enabled;
    return Container(
      margin: const EdgeInsets.only(bottom: BsSpace.md),
      padding: const EdgeInsets.all(BsSpace.lg),
      decoration: BoxDecoration(
        color: BsColors.paper,
        borderRadius: BorderRadius.circular(BsRadius.md),
        border: Border.all(color: BsColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.cloud_outlined, size: 18, color: BsColors.sky),
            const SizedBox(width: 8),
            Text('Stockage cloud (Supabase)',
                style: BsType.heading(16, w: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: _statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(_status,
                    style: BsType.body(11,
                        w: FontWeight.w700, color: _statusColor)),
              ]),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
              'Sauvegarde de la base et des photos dans le cloud. L\'application reste 100% utilisable hors ligne.',
              style: BsType.body(12, color: BsColors.slate)),
          const SizedBox(height: BsSpace.md),
          if (!configured)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BsColors.papyrus,
                borderRadius: BorderRadius.circular(BsRadius.sm),
                border: Border.all(color: BsColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NON CONFIGURÉ', style: BsType.eyebrow()),
                  const SizedBox(height: 4),
                  Text(
                    "Les clés vivent dans installer/supabase.env. Depuis VS Code, "
                    "lance la configuration « Skyblue (avec cloud) ». En production, "
                    "release.ps1 les injecte automatiquement.",
                    style: BsType.body(11, color: BsColors.slate),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: BsSpace.md),
              decoration: BoxDecoration(
                color: BsColors.sky.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(BsRadius.sm),
                border: Border.all(color: BsColors.sky.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.schedule, size: 16, color: BsColors.sky),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SAUVEGARDE AUTOMATIQUE — CHAQUE NUIT À 00:00',
                          style: BsType.eyebrow(color: BsColors.sky)),
                      const SizedBox(height: 2),
                      Text(_lastBackupLabel,
                          style: BsType.body(11, color: BsColors.slate)),
                    ],
                  ),
                ),
              ]),
            ),
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton.icon(
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_outlined, size: 16),
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        final r = await AutoBackup.runNow();
                        final last = await AutoBackup.lastBackup();
                        if (mounted) {
                          setState(() {
                            _busy = false;
                            _lastBackup = last;
                          });
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(r.message)));
                        }
                      },
                label: const Text('Sauvegarder maintenant'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.cloud_download_outlined, size: 16),
                onPressed: _busy
                    ? null
                    : () async {
                        final ok = await _confirmCloudRestore(context);
                        if (!ok) return;
                        setState(() => _busy = true);
                        final r = await CloudService.restoreLatestBackup();
                        if (mounted) {
                          setState(() => _busy = false);
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(r.message)));
                        }
                      },
                label: const Text('Restaurer depuis le cloud'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.sync, size: 16),
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        final msg = await MirrorService.syncAll();
                        if (mounted) {
                          setState(() => _busy = false);
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(msg)));
                        }
                      },
                label: const Text('Synchroniser les données'),
              ),
              IconButton(
                tooltip: 'Rafraîchir le statut',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Future<bool> _confirmCloudRestore(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Restaurer depuis le cloud ?'),
        content: const Text(
            'La base locale actuelle sera remplacée par la dernière sauvegarde cloud. L\'app doit être redémarrée après. Continuer ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Restaurer')),
        ],
      ),
    );
    return ok ?? false;
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _Section(
      {required this.title, required this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: BsSpace.md),
      padding: const EdgeInsets.all(BsSpace.lg),
      decoration: BoxDecoration(
        color: BsColors.paper,
        borderRadius: BorderRadius.circular(BsRadius.md),
        border: Border.all(color: BsColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: BsType.heading(16, w: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle, style: BsType.body(12, color: BsColors.slate)),
          const SizedBox(height: BsSpace.md),
          child,
        ],
      ),
    );
  }
}

/// Réglage du taux FC pour 1 USD — écrit dans la table `settings` et
/// répercuté immédiatement sur les PDF (facture + rapports).
class _CurrencySection extends ConsumerStatefulWidget {
  const _CurrencySection();
  @override
  ConsumerState<_CurrencySection> createState() => _CurrencySectionState();
}

class _CurrencySectionState extends ConsumerState<_CurrencySection> {
  final _ctrl = TextEditingController();
  bool _dirty = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rateAsync = ref.watch(rateProvider);
    final rate = rateAsync.asData?.value ?? Currency.defaultRate;
    if (!_dirty) _ctrl.text = rate.toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: BsSpace.md),
      padding: const EdgeInsets.all(BsSpace.lg),
      decoration: BoxDecoration(
        color: BsColors.paper,
        borderRadius: BorderRadius.circular(BsRadius.md),
        border: Border.all(color: BsColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.currency_exchange, size: 18, color: BsColors.sky),
            const SizedBox(width: 8),
            Text('Taux de change (FC → USD)',
                style: BsType.heading(16, w: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Text(
              'Utilisé uniquement pour afficher l\'équivalent dollar sur les factures et rapports PDF (« soit \$X »).',
              style: BsType.body(12, color: BsColors.slate)),
          const SizedBox(height: BsSpace.md),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('1 \$  =', style: BsType.body(15, w: FontWeight.w600)),
            const SizedBox(width: 10),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => _dirty = true),
                decoration:
                    const InputDecoration(suffixText: 'FC', isDense: true),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: !_dirty
                  ? null
                  : () async {
                      final v = double.tryParse(
                          _ctrl.text.trim().replaceAll(',', '.'));
                      if (v == null || v <= 0) return;
                      await ref.read(settingsRepoProvider).setRate(v);
                      if (context.mounted) {
                        setState(() => _dirty = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'Taux mis à jour : 1 \$ = ${v.toStringAsFixed(0)} FC')));
                      }
                    },
              child: const Text('Enregistrer'),
            ),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BsColors.papyrus,
              borderRadius: BorderRadius.circular(BsRadius.sm),
            ),
            child: Text(
                'Exemple : un total de ${moneyFc(100000)} s\'affichera sur le PDF comme ${moneyFc(100000)} (${moneyUsdFromFc(100000)}).',
                style: BsType.body(12, color: BsColors.slate)),
          ),
        ],
      ),
    );
  }
}

/// Section reset transactions — Super Admin uniquement.
///
/// Vide TOUTES les ventes + lignes de vente locales. Utilise UNIQUEMENT
/// avant lancement en production, pour repartir sur un historique propre
/// sans les ventes de test. Ne touche pas aux stocks, produits, chambres,
/// comptes ni réglages.
///
/// Double confirmation obligatoire : dialog + saisie de la chaîne
/// "SUPPRIMER TOUT" pour deverrouiller le bouton final.
class _ResetTransactionsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: BsSpace.md),
      padding: const EdgeInsets.all(BsSpace.lg),
      decoration: BoxDecoration(
        color: BsColors.paper,
        borderRadius: BorderRadius.circular(BsRadius.md),
        border: Border.all(color: BsColors.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber_outlined,
                size: 18, color: BsColors.danger),
            const SizedBox(width: 8),
            Text('Réinitialiser les transactions (lancement prod)',
                style: BsType.heading(16, w: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Text(
              'Vide toutes les ventes et lignes de vente locales. Comptes, '
              'produits, chambres, stocks et réglages sont conservés. '
              'À utiliser une seule fois avant le lancement en production, '
              'pour repartir sur un historique propre.',
              style: BsType.body(12, color: BsColors.slate)),
          const SizedBox(height: BsSpace.md),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BsColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(BsRadius.sm),
              border: Border.all(color: BsColors.danger.withValues(alpha: 0.3)),
            ),
            child: Text(
                'Action IRRÉVERSIBLE. Pense à faire une sauvegarde avant '
                '(Exporter la BDD ci-dessous) si tu veux garder les données de test.',
                style: BsType.body(11,
                    w: FontWeight.w600, color: BsColors.danger)),
          ),
          const SizedBox(height: BsSpace.md),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_sweep, size: 16),
            style: OutlinedButton.styleFrom(
              foregroundColor: BsColors.danger,
              side: const BorderSide(color: BsColors.danger),
            ),
            onPressed: () => _showResetDialog(context, ref),
            label: const Text('Vider l\'historique des ventes'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetDialog(BuildContext ctx, WidgetRef ref) async {
    final salesRepo = ref.read(salesRepoProvider);
    final count = await salesRepo.countAll();
    if (!ctx.mounted) return;
    if (count == 0) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('Aucune vente en base — rien à supprimer.')));
      return;
    }

    final confirmCtrl = TextEditingController();
    bool unlocked = false;
    await showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(builder: (context, setSt) {
        return AlertDialog(
          title: Text('Vider $count vente(s) ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  'Toutes les ventes ($count transactions) et leurs lignes vont être supprimées définitivement.\n\n'
                  'Cette action est IRRÉVERSIBLE.\n\n'
                  'Pour confirmer, tape "SUPPRIMER TOUT" ci-dessous :',
                  style: BsType.body(12)),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                autofocus: true,
                onChanged: (v) =>
                    setSt(() => unlocked = v.trim() == 'SUPPRIMER TOUT'),
                decoration: const InputDecoration(
                    hintText: 'SUPPRIMER TOUT', isDense: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.delete_forever, size: 16),
              style: FilledButton.styleFrom(backgroundColor: BsColors.danger),
              onPressed: unlocked
                  ? () async {
                      final deleted = await salesRepo.wipeAllSales();
                      if (!context.mounted) return;
                      Navigator.of(dialogCtx).pop();
                      ref.invalidate(recentSalesProvider);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            '$deleted vente(s) supprimée(s). Historique remis à zéro.'),
                        duration: const Duration(seconds: 5),
                      ));
                    }
                  : null,
              label: Text('Vider $count vente(s)'),
            ),
          ],
        );
      }),
    );
  }
}

/// Section version + bouton "Vérifier les mises à jour" — accessible
/// à tous les utilisateurs connectés (aucune permission requise).
class _AppUpdateSection extends ConsumerStatefulWidget {
  const _AppUpdateSection();
  @override
  ConsumerState<_AppUpdateSection> createState() => _AppUpdateSectionState();
}

class _AppUpdateSectionState extends ConsumerState<_AppUpdateSection> {
  bool _checking = false;
  String? _message;
  bool _messageIsError = false;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      final info = await UpdateService.instance.checkNow();
      if (!mounted) return;
      if (info == null) {
        setState(() {
          _checking = false;
          _messageIsError = false;
          _message = 'Vous êtes à jour.';
        });
      } else {
        setState(() {
          _checking = false;
          _messageIsError = false;
          _message =
              'Nouvelle version ${info.version} disponible — regarde la bannière en haut de l\'écran.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _messageIsError = true;
        _message = 'Impossible de vérifier : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch le provider pour reactualiser si une mise a jour est detectee.
    final availNotifier = ref.watch(updateAvailableProvider);
    final info = availNotifier.value;
    return Container(
      margin: const EdgeInsets.only(bottom: BsSpace.md),
      padding: const EdgeInsets.all(BsSpace.lg),
      decoration: BoxDecoration(
        color: BsColors.paper,
        borderRadius: BorderRadius.circular(BsRadius.md),
        border: Border.all(color: BsColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.system_update_alt, size: 18, color: BsColors.sky),
            const SizedBox(width: 8),
            Text('Version de l\'application',
                style: BsType.heading(16, w: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text('Version installée : ',
                style: BsType.body(12, color: BsColors.slate)),
            Text(kAppVersion, style: BsType.mono(13, w: FontWeight.w700)),
          ]),
          if (info != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              Text('Dernière disponible : ',
                  style: BsType.body(12, color: BsColors.slate)),
              Text(info.version,
                  style: BsType.mono(13,
                      w: FontWeight.w700, color: BsColors.sunrise)),
            ]),
          ],
          const SizedBox(height: BsSpace.md),
          Row(children: [
            OutlinedButton.icon(
              icon: _checking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 16),
              onPressed: _checking ? null : _check,
              label: Text(
                  _checking ? 'Vérification…' : 'Vérifier les mises à jour'),
            ),
            const SizedBox(width: 12),
            if (_message != null)
              Expanded(
                child: Text(
                  _message!,
                  style: BsType.body(12,
                      color:
                          _messageIsError ? BsColors.danger : BsColors.success,
                      w: FontWeight.w600),
                ),
              ),
          ]),
        ],
      ),
    );
  }
}

/// La récupération des données miroir, en version qui n'efface rien.
///
/// Elle ramène ce que ramène la récupération d'urgence — catalogue,
/// chambres, clients, sociétés, séjours, comptes ET ventes — mais en
/// AJOUTANT ce qui manque au lieu de raser la base d'abord. Aucune vente
/// locale n'est touchée, le stock du poste reste intact. C'est ce qui
/// permet de la laisser au gérant.
///
/// Les ventes ne sont relues qu'ici, pas dans le cycle des 15 secondes :
/// relire toute la table à chaque tour coûterait trop cher.
class _PullNowButton extends ConsumerStatefulWidget {
  const _PullNowButton();
  @override
  ConsumerState<_PullNowButton> createState() => _PullNowButtonState();
}

class _PullNowButtonState extends ConsumerState<_PullNowButton> {
  bool _busy = false;
  String? _message;

  Future<void> _recuperer() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final erreurs = <String>[];

    await MirrorPullService.instance.pullNow();
    final errSynchro = MirrorPullService.instance.lastError;
    if (errSynchro != null) erreurs.add(describeError(errSynchro).message);

    var ventes = 0;
    try {
      ventes = await MirrorService.pullSalesIntoLocal();
    } catch (e) {
      erreurs.add('Ventes : ${describeError(e).message}');
    }

    try {
      await ref.read(usersRepoProvider).syncFromCloud();
    } catch (e) {
      erreurs.add('Comptes : ${describeError(e).message}');
    }

    if (!mounted) return;
    if (ventes > 0) {
      ref.invalidate(recentSalesProvider);
      ref.invalidate(metricsWeekProvider);
    }
    setState(() {
      _busy = false;
      _message = erreurs.isNotEmpty
          ? erreurs.join('\n')
          : ventes > 0
              ? 'Données à jour — $ventes vente(s) récupérée(s) des autres '
                  'postes.'
              : 'Données à jour.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          icon: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.cloud_download_outlined, size: 16),
          onPressed: _busy ? null : _recuperer,
          label: const Text('Récupérer maintenant'),
        ),
        if (_message != null) ...[
          const SizedBox(height: BsSpace.sm),
          Text(_message!, style: BsType.body(12, color: BsColors.slate)),
        ],
      ],
    );
  }
}

/// Contrôle de l'horloge du poste.
///
/// Une horloge fausse ne casse rien de visible : l'application continue,
/// les tickets s'impriment, le personnel lit l'heure qu'il attend. Seul
/// l'instant ABSOLU part de travers, et il n'y a que la comptabilité
/// pour s'en apercevoir — trop tard. D'où ce contrôle, en tête de page.
class _HorlogeSection extends StatefulWidget {
  const _HorlogeSection();

  @override
  State<_HorlogeSection> createState() => _HorlogeSectionState();
}

class _HorlogeSectionState extends State<_HorlogeSection> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Si personne n'a encore mesuré, on le fait en arrivant ici.
    if (HorlogeService.instance.derive == null) unawaited(_mesurer());
  }

  Future<void> _mesurer() async {
    setState(() => _busy = true);
    await HorlogeService.instance.mesurer();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final h = HorlogeService.instance;
    final alerte = h.avertissement;

    return _Section(
      title: "Horloge du poste",
      subtitle: alerte == null
          ? "L'heure vient du serveur : identique sur tous les postes"
          : "L'heure de Windows dérive — sans effet tant qu'on est en ligne",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (alerte != null)
            Container(
              padding: const EdgeInsets.all(BsSpace.smd),
              decoration: BoxDecoration(
                color: BsColors.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: BsColors.danger.withValues(alpha: 0.35)),
              ),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.schedule_outlined,
                    size: 18, color: BsColors.danger),
                const SizedBox(width: BsSpace.sm),
                Expanded(
                  child: Text(alerte,
                      style: BsType.body(13, color: BsColors.danger)),
                ),
              ]),
            )
          else if (h.derive != null) ...[
            Text(
                "Heure prise sur ${h.sourceUtilisee ?? 'le serveur'} · "
                "${h.derive!.inSeconds.abs()} s d'écart avec l'horloge de "
                'Windows.',
                style: BsType.body(13, color: BsColors.slate)),
            // Deux horloges indépendantes qui se contredisent : ça ne
            // change rien à ce qu'on enregistre — Supabase fait foi —
            // mais c'est le genre de chose qu'on veut savoir avant que
            // ça devienne un écart de caisse.
            if (h.desaccord != null) ...[
              const SizedBox(height: BsSpace.xs),
              Text(
                  'Le serveur et une horloge mondiale ne sont pas '
                  "d'accord (${h.desaccord!.inMinutes} min). Les ventes "
                  'restent datées sur le serveur. À signaler.',
                  style: BsType.body(13, color: BsColors.warning)),
            ],
          ] else
            Text(
                _busy
                    ? "Mesure en cours…"
                    : "Pas encore vérifiée — il faut une connexion.",
                style: BsType.body(13, color: BsColors.slate)),
          const SizedBox(height: BsSpace.smd),
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule, size: 16),
            onPressed: _busy ? null : _mesurer,
            label: const Text("Vérifier l'horloge"),
          ),
        ],
      ),
    );
  }
}

/// Les ventes qui n'ont pas encore atteint le serveur.
///
/// Ce n'est pas un indicateur de confort. Avant lui, une vente poussée
/// sans succès l'était en silence : `catch (_) {}`, aucune trace, aucun
/// compteur. Tant que le rattrapage automatique fonctionnait, ça ne se
/// voyait pas — et le jour où il aurait cessé de fonctionner, ça ne se
/// serait pas vu davantage.
class _FileVentesSection extends StatefulWidget {
  const _FileVentesSection();

  @override
  State<_FileVentesSection> createState() => _FileVentesSectionState();
}

class _FileVentesSectionState extends State<_FileVentesSection> {
  int? _enAttente;
  DateTime? _plusAncienne;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_relire());
  }

  Future<void> _relire() async {
    final f = VentesOutbox.instance;
    final n = await f.enAttente();
    final a = await f.plusAncienneEnAttente();
    if (mounted) {
      setState(() {
        _enAttente = n;
        _plusAncienne = a;
      });
    }
  }

  Future<void> _envoyer() async {
    setState(() => _busy = true);
    final n = await VentesOutbox.instance.vider();
    await _relire();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n == 0
            ? "Rien n'est parti — vérifie la connexion."
            : '$n vente(s) envoyée(s).')));
  }

  @override
  Widget build(BuildContext context) {
    final n = _enAttente;
    // Une vente qui attend depuis une heure n'est pas la même chose
    // qu'une vente encaissée il y a trente secondes.
    final vieille = _plusAncienne != null &&
        Horloge.maintenant().difference(_plusAncienne!) >
            const Duration(hours: 1);

    return _Section(
      title: 'Ventes en ligne',
      subtitle: n == null || n == 0
          ? 'Toutes les ventes sont en lieu sûr sur le serveur'
          : "$n vente(s) n'ont pas encore quitté ce poste",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (n != null && n > 0)
            Container(
              padding: const EdgeInsets.all(BsSpace.smd),
              decoration: BoxDecoration(
                color: (vieille ? BsColors.danger : BsColors.warning)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: (vieille ? BsColors.danger : BsColors.warning)
                        .withValues(alpha: 0.35)),
              ),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.cloud_upload_outlined,
                    size: 18,
                    color: vieille ? BsColors.danger : BsColors.warning),
                const SizedBox(width: BsSpace.sm),
                Expanded(
                  child: Text(
                      vieille
                          ? "La plus ancienne attend depuis plus d'une "
                              "heure. Ces ventes n'existent que sur ce "
                              'poste : si le disque lâche, elles sont '
                              'perdues.'
                          : "Elles partiront d'elles-mêmes dès que la "
                              'connexion le permettra.',
                      style: BsType.body(13,
                          color: vieille ? BsColors.danger : BsColors.slate)),
                ),
              ]),
            )
          else
            Text(
                n == null
                    ? 'Vérification…'
                    : 'Rien en attente : le serveur a tout confirmé.',
                style: BsType.body(13, color: BsColors.slate)),
          const SizedBox(height: BsSpace.smd),
          Row(children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.cloud_upload_outlined, size: 16),
              onPressed: _busy || (n ?? 0) == 0 ? null : _envoyer,
              label: const Text('Envoyer maintenant'),
            ),
            const SizedBox(width: BsSpace.sm),
            IconButton(
              tooltip: 'Rafraîchir',
              onPressed: _busy ? null : _relire,
              icon: const Icon(Icons.refresh, size: 18),
            ),
          ]),
        ],
      ),
    );
  }
}
