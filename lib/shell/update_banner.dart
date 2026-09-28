import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/update_service.dart';
import '../core/user_error.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Banniere discrete en haut de l'app : "Nouvelle version dispo — Installer".
///
/// Auto-hide si aucune mise a jour n'est detectee (rend un [SizedBox.shrink]).
/// Affichee sinon a chaque ecran (via [AppShell]).
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(updateAvailableProvider);
    final info = notifier.value;
    if (info == null) return const SizedBox.shrink();

    return Material(
      color: BsColors.sunrise.withValues(alpha: 0.12),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: BsColors.sunrise.withValues(alpha: 0.4), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: BsSpace.lg, vertical: BsSpace.sm),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: BsColors.sunrise.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(BsRadius.sm),
            ),
            child: const Icon(Icons.system_update,
                size: 18, color: BsColors.sunrise),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nouvelle version disponible — ${info.version}',
                    style: BsType.body(13,
                        w: FontWeight.w700, color: BsColors.ink)),
                if (info.notes != null && info.notes!.isNotEmpty)
                  Text(info.notes!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BsType.body(11, color: BsColors.slate)),
              ],
            ),
          ),
          if (!info.mandatory)
            TextButton(
              onPressed: () => UpdateService.instance.dismiss(),
              child: const Text('Plus tard'),
            ),
          const SizedBox(width: 4),
          FilledButton.icon(
            icon: const Icon(Icons.download, size: 16),
            onPressed: () => _startUpdate(context, ref),
            style: FilledButton.styleFrom(
              backgroundColor: BsColors.sunrise,
              foregroundColor: Colors.white,
            ),
            label: const Text('Mettre à jour'),
          ),
        ]),
      ),
    );
  }

  Future<void> _startUpdate(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogCtx) => const _UpdateProgressDialog(),
    );
    // Lance le download. Si tout se passe bien, la methode fait exit(0)
    // avant de retourner (l'installeur remplace l'app). Si echec, on
    // retourne false et le dialog affichera l'erreur.
    await UpdateService.instance.downloadAndInstall(silent: false);
  }
}

/// Dialog affiche pendant le download + verification.
///
/// Ne peut pas etre ferme (barrierDismissible: false) tant que le
/// process est en cours. Se ferme automatiquement quand l'app quitte
/// (exit(0) apres lancement de l'installeur) OU si erreur → bouton
/// "Fermer" apparait pour retenter plus tard.
class _UpdateProgressDialog extends ConsumerWidget {
  const _UpdateProgressDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressNotifier = ref.watch(updateProgressProvider);
    final errorNotifier = ref.watch(updateErrorProvider);
    final infoNotifier = ref.watch(updateAvailableProvider);

    final progress = progressNotifier.value;
    final error = errorNotifier.value;
    final info = infoNotifier.value;

    if (error != null) {
      // Le détail technique (SocketException, hôte, port…) ne s'affiche
      // plus : il part au journal d'erreurs. L'utilisateur lit pourquoi
      // la mise à jour a échoué et ce qu'il peut faire.
      final decrit = describeError(error);
      return AlertDialog(
        icon: Icon(
            decrit.kind == ErrorKind.offline
                ? Icons.cloud_off_outlined
                : Icons.error_outline,
            size: 32,
            color: decrit.kind == ErrorKind.offline
                ? BsColors.slate
                : BsColors.danger),
        title: Text('Mise à jour impossible'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(decrit.message,
                textAlign: TextAlign.center,
                style: BsType.body(13, color: BsColors.slate)),
            if (decrit.advice != null) ...[
              const SizedBox(height: 6),
              Text(decrit.advice!,
                  textAlign: TextAlign.center,
                  style: BsType.body(12, color: BsColors.slateSoft)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      );
    }

    final pct = progress == null
        ? 0.0
        : progress.total > 0
            ? progress.ratio.clamp(0.0, 1.0)
            : null;
    final receivedMb =
        progress == null ? 0 : (progress.received / (1024 * 1024)).round();
    final totalMb = (info?.sizeBytes ?? 0) / (1024 * 1024);

    return AlertDialog(
      title: Text(info == null
          ? 'Mise à jour'
          : 'Mise à jour vers Skyblue ${info.version}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(BsRadius.sm),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: BsColors.papyrus,
              color: BsColors.sunrise,
            ),
          ),
          const SizedBox(height: 10),
          Text(
              progress == null
                  ? 'Connexion au serveur...'
                  : totalMb > 0
                      ? 'Téléchargement... $receivedMb Mo / ${totalMb.toStringAsFixed(0)} Mo'
                      : 'Téléchargement... $receivedMb Mo',
              style: BsType.body(12, color: BsColors.slate)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BsColors.papyrus,
              borderRadius: BorderRadius.circular(BsRadius.sm),
            ),
            child: Text(
                'L\'app va se fermer automatiquement à la fin. Elle rouvrira toute seule après l\'installation. Tes données sont conservées.',
                style: BsType.body(11, color: BsColors.slate)),
          ),
        ],
      ),
    );
  }
}
