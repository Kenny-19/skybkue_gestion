import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/cat_ui.dart';
import '../../core/format.dart';
import '../../data/schema.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Ce qu'un encaissement rapporte : combien, et comment.
class Encaissement {
  const Encaissement(this.montantCents, this.payment);
  final int montantCents;
  final DbPayment payment;
}

/// Saisie d'un versement sur une dette.
///
/// Le montant est PRÉ-REMPLI au solde restant, parce que c'est le cas de
/// loin le plus fréquent : le client vient solder. Celui qui verse un
/// acompte corrige le champ. L'inverse — champ vide à remplir à chaque
/// fois — ferait payer le cas courant pour le cas rare.
///
/// Le bouton dit toujours ce qui va se passer : « Solder » quand le
/// montant couvre tout, « Encaisser un acompte » sinon, avec le reste
/// annoncé. Personne ne doit découvrir après coup qu'une dette est
/// restée ouverte.
Future<Encaissement?> demanderEncaissement(
  BuildContext context, {
  required String ticket,
  required String qui,
  required int totalCents,
  required int dejaPayeCents,
}) {
  final reste = (totalCents - dejaPayeCents).clamp(0, totalCents);
  return showDialog<Encaissement>(
    context: context,
    builder: (ctx) => _Dialogue(
      ticket: ticket,
      qui: qui,
      totalCents: totalCents,
      dejaPayeCents: dejaPayeCents,
      resteCents: reste,
    ),
  );
}

class _Dialogue extends StatefulWidget {
  const _Dialogue({
    required this.ticket,
    required this.qui,
    required this.totalCents,
    required this.dejaPayeCents,
    required this.resteCents,
  });

  final String ticket;
  final String qui;
  final int totalCents;
  final int dejaPayeCents;
  final int resteCents;

  @override
  State<_Dialogue> createState() => _DialogueState();
}

class _DialogueState extends State<_Dialogue> {
  late final TextEditingController _montant =
      TextEditingController(text: (widget.resteCents / 100).round().toString());
  DbPayment _payment = DbPayment.values.first;
  String? _erreur;

  @override
  void dispose() {
    _montant.dispose();
    super.dispose();
  }

  /// Montant saisi, en cents. Null si la saisie n'est pas exploitable.
  int? get _cents {
    final t = _montant.text.trim().replaceAll(' ', '');
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    if (v == null || v <= 0) return null;
    return v * 100;
  }

  void _valider() {
    final c = _cents;
    if (c == null) {
      setState(() => _erreur = 'Saisis un montant.');
      return;
    }
    if (c > widget.resteCents) {
      setState(() =>
          _erreur = 'Le client ne doit que ${moneyCents(widget.resteCents)}.');
      return;
    }
    Navigator.of(context).pop(Encaissement(c, _payment));
  }

  @override
  Widget build(BuildContext context) {
    final c = _cents ?? 0;
    final solde = c >= widget.resteCents && c > 0;
    final apres = (widget.resteCents - c).clamp(0, widget.resteCents);

    return Dialog(
      backgroundColor: BsColors.paper,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BsRadius.md)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(BsSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ENCAISSER', style: BsType.eyebrow()),
              const SizedBox(height: BsSpace.xs2),
              Text('${widget.ticket} · ${widget.qui}',
                  style: BsType.display(20, w: FontWeight.w700)),
              const SizedBox(height: BsSpace.sm),
              _ligne('Total', moneyCents(widget.totalCents)),
              if (widget.dejaPayeCents > 0)
                _ligne('Déjà reçu', moneyCents(widget.dejaPayeCents)),
              _ligne('Reste dû', moneyCents(widget.resteCents), fort: true),
              const SizedBox(height: BsSpace.md),
              TextField(
                controller: _montant,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() => _erreur = null),
                onSubmitted: (_) => _valider(),
                decoration: const InputDecoration(
                    labelText: 'Montant reçu (FC)',
                    prefixIcon: Icon(Icons.payments_outlined)),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: BsSpace.sm),
                Text(_erreur!,
                    style: BsType.body(13,
                        w: FontWeight.w600, color: BsColors.danger)),
              ],
              const SizedBox(height: BsSpace.md),
              Text('MODE DE PAIEMENT REÇU', style: BsType.eyebrow()),
              const SizedBox(height: BsSpace.sm),
              Wrap(
                spacing: BsSpace.sm,
                runSpacing: BsSpace.sm,
                children: [
                  for (final p in DbPayment.values)
                    ChoiceChip(
                      selected: _payment == p,
                      onSelected: (_) => setState(() => _payment = p),
                      avatar: Icon(p.icon, size: 15),
                      label: Text(p.label),
                    ),
                ],
              ),
              const SizedBox(height: BsSpace.md),
              // Ce qui va se passer, dit avant de cliquer.
              Text(
                solde
                    ? 'Cette dette sera soldée.'
                    : 'Acompte : il restera ${moneyCents(apres)} à recouvrer.',
                style: BsType.body(13,
                    color: solde ? BsColors.slate : BsColors.warning),
              ),
              const SizedBox(height: BsSpace.md),
              SizedBox(
                height: BsControl.primary,
                child: FilledButton(
                  onPressed: _valider,
                  child:
                      Text(solde ? 'Solder la dette' : 'Encaisser l\'acompte'),
                ),
              ),
              const SizedBox(height: BsSpace.xs),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ligne(String libelle, String valeur, {bool fort = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: BsSpace.xxs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(libelle, style: BsType.body(13, color: BsColors.slate)),
            Text(valeur,
                style: BsType.body(13,
                    w: fort ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      );
}
