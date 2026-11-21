import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/temps.dart';
import '../services/connexion_service.dart';
import '../services/stock_service.dart';
import '../services/ventes_outbox.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Bandeau affiché en tête de tous les écrans quand le serveur ne répond
/// plus.
///
/// L'application travaille en ligne d'abord ; pendant une coupure, elle
/// continue sur la copie locale et met les opérations en file. La personne
/// doit le SAVOIR : ce qu'elle voit n'est plus forcément à jour, et ce
/// qu'elle fait partira plus tard.
class BandeauHorsLigne extends StatefulWidget {
  const BandeauHorsLigne({super.key, ConnexionService? connexion})
      : _connexion = connexion;
  final ConnexionService? _connexion;

  @override
  State<BandeauHorsLigne> createState() => _BandeauHorsLigneState();
}

class _BandeauHorsLigneState extends State<BandeauHorsLigne> {
  ConnexionService get _cx => widget._connexion ?? ConnexionService.instance;
  Timer? _minuterie;
  int _ventes = 0;
  int _stock = 0;

  @override
  void initState() {
    super.initState();
    _cx.etat.addListener(_suivre);
    _suivre();
  }

  @override
  void dispose() {
    _cx.etat.removeListener(_suivre);
    _minuterie?.cancel();
    super.dispose();
  }

  /// Compte des opérations en attente, relu toutes les 5 s pendant la
  /// coupure seulement.
  void _suivre() {
    if (!mounted) return;
    setState(() {});
    if (_cx.estHorsLigne) {
      _minuterie ??=
          Timer.periodic(const Duration(seconds: 5), (_) => _compter());
      _compter();
    } else {
      _minuterie?.cancel();
      _minuterie = null;
    }
  }

  Future<void> _compter() async {
    try {
      final v = await VentesOutbox.instance.enAttente();
      final s = await StockService.instance.enAttente();
      if (mounted && (v != _ventes || s != _stock)) {
        setState(() {
          _ventes = v;
          _stock = s;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_cx.estHorsLigne) return const SizedBox.shrink();
    final depuis = _cx.horsLigneDepuis;
    final enAttente = [
      if (_ventes > 0) '$_ventes vente${_ventes > 1 ? 's' : ''}',
      if (_stock > 0) '$_stock mouvement${_stock > 1 ? 's' : ''} de stock',
    ];
    return Material(
      color: BsColors.warning.withValues(alpha: 0.16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: BsSpace.xl, vertical: BsSpace.sm),
        child: Row(children: [
          const Icon(Icons.cloud_off, size: 18, color: BsColors.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              [
                'Hors ligne${depuis == null ? '' : ' depuis ${DateFormat('HH:mm').format(aLubumbashi(depuis))}'}',
                enAttente.isEmpty
                    ? 'ce que vous faites sera envoyé au serveur au retour du réseau'
                    : '${enAttente.join(' et ')} en attente, envoyés au retour du réseau',
              ].join(' · '),
              style: BsType.body(12, w: FontWeight.w600),
            ),
          ),
        ]),
      ),
    );
  }
}
