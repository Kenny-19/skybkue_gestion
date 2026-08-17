import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import '../../core/auth.dart';
import '../../data/providers.dart';
import '../../services/auto_backup.dart';
import '../../services/backup_service.dart';
import '../../services/cloud_service.dart';
import '../../shell/app_shell.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider).user;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            eyebrow: 'Paramètres',
            title: 'Configuration',
            subtitle: 'Sauvegarde, mot de passe, informations système',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  title: 'Mon mot de passe',
                  subtitle: 'Change-le régulièrement, surtout depuis le compte par défaut',
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.lock_outline, size: 16),
                    onPressed:
                        me == null ? null : () => _showChangePassword(context, ref, me.id),
                    label: const Text('Changer mon mot de passe'),
                  ),
                ),
                _Section(
                  title: 'Emplacement de la base',
                  subtitle: 'Dossier où le fichier de données est stocké sur ce PC',
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
            ),
          ),
          const SizedBox(height: BsSpace.xxl),
        ],
      ),
    );
  }

  Future<bool> _confirmImport(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Restaurer une sauvegarde ?'),
        content: const Text(
            'La base actuelle sera remplacée par le fichier choisi. L\'app doit être redémarrée après. Continuer ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
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
      builder: (_) => AlertDialog(
        title: const Text('Restauration effectuée'),
        content: const Text(
            'La base a été restaurée. Ferme et relance l\'application pour que les changements prennent effet.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(BsRadius.md)),
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
                        await ref
                            .read(usersRepoProvider)
                            .resetPassword(userId, pwd.text);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Mot de passe changé')));
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
    return 'Dernière sauvegarde : ${DateFormat("d MMM y 'à' HH:mm", 'fr_FR').format(_lastBackup!)}';
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
                    'Renseigne l\'URL et la clé Supabase dans lib/core/cloud_config.dart pour activer le cloud.',
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
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(r.message)));
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
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(r.message)));
                        }
                      },
                label: const Text('Restaurer depuis le cloud'),
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
      builder: (_) => AlertDialog(
        title: const Text('Restaurer depuis le cloud ?'),
        content: const Text(
            'La base locale actuelle sera remplacée par la dernière sauvegarde cloud. L\'app doit être redémarrée après. Continuer ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
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
  const _Section({required this.title, required this.subtitle, required this.child});
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
