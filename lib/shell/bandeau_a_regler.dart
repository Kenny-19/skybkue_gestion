import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/temps.dart';
import '../data/database.dart';
import '../services/operations_service.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Opérations faites hors ligne que le serveur a REFUSÉES au retour du
/// réseau (la chambre avait été prise sur un autre poste entre-temps…).
///
/// Elles ne disparaissent jamais en silence : un bandeau les signale sur
/// tous les écrans tant qu'un gérant ne les a pas réglées.
class BandeauARegler extends StatelessWidget {
  const BandeauARegler({super.key, OperationsService? operations})
      : _ops = operations;
  final OperationsService? _ops;

  @override
  Widget build(BuildContext context) {
    final ops = _ops ?? OperationsService.instance;
    return StreamBuilder<List<Operation>>(
      stream: ops.watchARegler(),
      builder: (context, snap) {
        final liste = snap.data ?? const <Operation>[];
        if (liste.isEmpty) return const SizedBox.shrink();
        return Material(
          color: BsColors.danger.withValues(alpha: 0.12),
          child: InkWell(
            onTap: () => showDialog(
                context: context,
                builder: (_) => _ListeARegler(operations: ops)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: BsSpace.xl, vertical: BsSpace.sm),
              child: Row(children: [
                const Icon(Icons.report_outlined,
                    size: 18, color: BsColors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    liste.length == 1
                        ? '1 opération faite hors ligne a été refusée par le '
                            'serveur : à régler.'
                        : '${liste.length} opérations faites hors ligne ont été '
                            'refusées par le serveur : à régler.',
                    style: BsType.body(12,
                        w: FontWeight.w600, color: BsColors.danger),
                  ),
                ),
                Text('Voir',
                    style: BsType.body(12,
                        w: FontWeight.w700, color: BsColors.danger)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _ListeARegler extends StatelessWidget {
  const _ListeARegler({required this.operations});
  final OperationsService operations;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d MMM 'à' HH:mm", 'fr_FR');
    return Dialog(
      backgroundColor: BsColors.paper,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: StreamBuilder<List<Operation>>(
            stream: operations.watchARegler(),
            builder: (context, snap) {
              final liste = snap.data ?? const <Operation>[];
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('À RÉGLER',
                      style: BsType.eyebrow(color: BsColors.danger)),
                  const SizedBox(height: 6),
                  Text('Refusé par le serveur au retour du réseau',
                      style: BsType.display(20, w: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                      "Ces opérations ont été faites sur ce poste pendant une "
                      "coupure. Le serveur, qui voit tous les postes, les a "
                      "refusées : la situation réelle est celle du serveur. "
                      "Corrigez si besoin (autre chambre, départ déjà fait…), "
                      "puis marquez comme réglé.",
                      style: BsType.body(12, color: BsColors.slate)),
                  const SizedBox(height: 16),
                  if (liste.isEmpty)
                    Text('Tout est réglé.',
                        style: BsType.body(13, w: FontWeight.w600))
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: liste.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 20, color: BsColors.line),
                        itemBuilder: (_, i) {
                          final o = liste[i];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(o.libelle,
                                        style: BsType.body(13,
                                            w: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(
                                        'Fait le ${fmt.format(aLubumbashi(o.creeLe))}'
                                        '${o.auteur == null ? '' : ' par ${o.auteur}'}',
                                        style: BsType.body(11,
                                            color: BsColors.slate)),
                                    const SizedBox(height: 4),
                                    Text(o.motif ?? '',
                                        style: BsType.body(12,
                                            color: BsColors.danger)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: () =>
                                    operations.marquerReglee(o.opId),
                                child: const Text('Réglé'),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Fermer')),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
