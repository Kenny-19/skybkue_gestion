import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Affiche le refus du serveur (chambre déjà prise sur un autre poste…).
///
/// Rien n'a été changé : la personne doit le savoir, et savoir pourquoi.
void signalerRefus(BuildContext context, Object refus) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
    backgroundColor: BsColors.danger,
    duration: const Duration(seconds: 8),
    content: Text('Refusé : $refus Rien n\'a été changé.',
        style: BsType.body(13, w: FontWeight.w600, color: Colors.white)),
  ));
}
