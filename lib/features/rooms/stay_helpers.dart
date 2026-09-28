import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/discount.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/schema.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Sélection d'un client (fidélité) — champ nom + champ téléphone.
///
/// - Debounced 200ms : tape → recherche dans la BDD locale par nom/téléphone.
/// - Si un client existant matche : chip "Client fidèle · N séjours".
/// - Rien à sélectionner explicitement : le parent lit `nameCtrl.text` et
///   `phoneCtrl.text` puis appelle `ClientsRepo.findOrCreate(...)` au
///   moment de valider.
class ClientLookupField extends ConsumerStatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final bool autofocusName;
  const ClientLookupField({
    super.key,
    required this.nameCtrl,
    required this.phoneCtrl,
    this.autofocusName = false,
  });

  @override
  ConsumerState<ClientLookupField> createState() => _ClientLookupFieldState();
}

class _ClientLookupFieldState extends ConsumerState<ClientLookupField> {
  Timer? _debounce;
  Client? _match;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    widget.nameCtrl.addListener(_scheduleLookup);
    widget.phoneCtrl.addListener(_scheduleLookup);
  }

  @override
  void dispose() {
    widget.nameCtrl.removeListener(_scheduleLookup);
    widget.phoneCtrl.removeListener(_scheduleLookup);
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleLookup() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _lookup);
  }

  Future<void> _lookup() async {
    final phone = widget.phoneCtrl.text.trim();
    final name = widget.nameCtrl.text.trim();
    if (phone.length < 3 && name.length < 3) {
      if (mounted && _match != null) setState(() => _match = null);
      return;
    }
    setState(() => _searching = true);
    final repo = ref.read(clientsRepoProvider);
    List<Client> results = [];
    if (phone.length >= 3) {
      results = await repo.search(phone, limit: 3);
    }
    if (results.isEmpty && name.length >= 3) {
      results = await repo.search(name, limit: 3);
    }
    if (!mounted) return;
    setState(() {
      _searching = false;
      _match = results.isEmpty ? null : results.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('NOM DU CLIENT', style: BsType.eyebrow()),
        const SizedBox(height: 6),
        TextField(
          controller: widget.nameCtrl,
          autofocus: widget.autofocusName,
          decoration: const InputDecoration(
              hintText: 'ex. M. Kabongo / Afrinvest SARL'),
        ),
        const SizedBox(height: 10),
        Text('TÉLÉPHONE (optionnel — clé de fidélité)',
            style: BsType.eyebrow()),
        const SizedBox(height: 6),
        TextField(
          controller: widget.phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: '+243 …',
            prefixIcon: Icon(Icons.phone_outlined, size: 16),
            isDense: true,
          ),
        ),
        if (_match != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: BsColors.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(BsRadius.sm),
              border:
                  Border.all(color: BsColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.verified_user,
                  size: 14, color: BsColors.success),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _match!.visitsCount == 0
                      ? 'Client déjà enregistré : ${_match!.fullName}'
                      : 'Client fidèle · ${_match!.visitsCount} séjour(s) — ${_match!.fullName}',
                  style: BsType.body(11,
                      w: FontWeight.w700, color: BsColors.success),
                ),
              ),
            ]),
          ),
        ] else if (_searching) ...[
          const SizedBox(height: 6),
          Text('Recherche…', style: BsType.body(10, color: BsColors.slateSoft)),
        ],
      ],
    );
  }
}

/// Section "Prise en charge" avec 2 modes :
///   - Le client paie lui-même (défaut, `selected = null`)
///   - Prise en charge par un tiers (société ou personne)
///
/// Autocomplete parmi les payers existants + bouton "+ Nouveau" qui
/// ouvre un mini-dialog inline. Le parent lit `selected` au moment de
/// valider.
class PayerPickerSection extends ConsumerStatefulWidget {
  final Payer? initial;
  final ValueChanged<Payer?> onChanged;
  const PayerPickerSection({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  ConsumerState<PayerPickerSection> createState() => _PayerPickerSectionState();
}

class _PayerPickerSectionState extends ConsumerState<PayerPickerSection> {
  late bool _thirdParty;
  Payer? _selected;
  final _searchCtrl = TextEditingController();
  List<Payer> _results = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _thirdParty = widget.initial != null;
    if (_selected != null) _searchCtrl.text = _selected!.name;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      final res = await ref.read(payersRepoProvider).search(q);
      if (!mounted) return;
      setState(() => _results = res);
    });
  }

  Future<void> _newPayer() async {
    final created = await showDialog<Payer>(
      context: context,
      builder: (_) => const _NewPayerDialog(),
    );
    if (!mounted || created == null) return;
    setState(() {
      _selected = created;
      _searchCtrl.text = created.name;
      _results = const [];
    });
    widget.onChanged(created);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('PRISE EN CHARGE', style: BsType.eyebrow()),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: false,
              groupValue: _thirdParty,
              onChanged: (v) {
                setState(() {
                  _thirdParty = v ?? false;
                  if (!_thirdParty) _selected = null;
                });
                widget.onChanged(_selected);
              },
              title: Text('Le client paie lui-même', style: BsType.body(12)),
            ),
          ),
          Expanded(
            child: RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: true,
              groupValue: _thirdParty,
              onChanged: (v) {
                setState(() => _thirdParty = v ?? false);
              },
              title: Text('Société / tiers', style: BsType.body(12)),
            ),
          ),
        ]),
        if (_thirdParty) ...[
          const SizedBox(height: 4),
          TextField(
            controller: _searchCtrl,
            onChanged: _scheduleSearch,
            decoration: InputDecoration(
              hintText: 'Rechercher une société / un tiers…',
              prefixIcon: const Icon(Icons.business_outlined, size: 16),
              isDense: true,
              suffixIcon: IconButton(
                tooltip: 'Nouvelle société',
                icon: const Icon(Icons.add_circle_outline, size: 18),
                onPressed: _newPayer,
              ),
            ),
          ),
          if (_selected != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: BsColors.sky.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(BsRadius.sm),
                border: Border.all(color: BsColors.sky.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle, size: 14, color: BsColors.sky),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      'Facturation à : ${_selected!.name}${_selected!.taxId != null && _selected!.taxId!.isNotEmpty ? " · " + _selected!.taxId! : ""}',
                      style: BsType.body(11,
                          w: FontWeight.w700, color: BsColors.sky)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selected = null;
                      _searchCtrl.clear();
                    });
                    widget.onChanged(null);
                  },
                  child: Text('Changer',
                      style: BsType.body(11,
                          w: FontWeight.w700, color: BsColors.slate)),
                ),
              ]),
            ),
          ] else if (_results.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                border: Border.all(color: BsColors.line),
                borderRadius: BorderRadius.circular(BsRadius.sm),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final p = _results[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                        p.type == DbPayerType.company
                            ? Icons.business
                            : Icons.person_outline,
                        size: 16),
                    title: Text(p.name, style: BsType.body(12)),
                    subtitle: p.taxId != null && p.taxId!.isNotEmpty
                        ? Text(p.taxId!,
                            style: BsType.body(10, color: BsColors.slate))
                        : null,
                    onTap: () {
                      setState(() {
                        _selected = p;
                        _searchCtrl.text = p.name;
                        _results = const [];
                      });
                      widget.onChanged(p);
                    },
                  );
                },
              ),
            ),
          ] else if (_searchCtrl.text.trim().length >= 2) ...[
            const SizedBox(height: 6),
            Row(children: [
              Text('Aucun tiers trouvé.',
                  style: BsType.body(11, color: BsColors.slate)),
              const SizedBox(width: 6),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 14),
                onPressed: _newPayer,
                label: const Text('Créer'),
              ),
            ]),
          ],
        ],
      ],
    );
  }
}

/// Dialog inline pour créer un nouveau payeur (société / tiers).
class _NewPayerDialog extends ConsumerStatefulWidget {
  const _NewPayerDialog();
  @override
  ConsumerState<_NewPayerDialog> createState() => _NewPayerDialogState();
}

class _NewPayerDialogState extends ConsumerState<_NewPayerDialog> {
  final _name = TextEditingController();
  final _taxId = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  DbPayerType _type = DbPayerType.company;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _taxId.dispose();
    _address.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _err = 'Le nom est requis.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final id = await ref.read(payersRepoProvider).create(
            name: _name.text.trim(),
            type: _type,
            taxId: _taxId.text.trim(),
            address: _address.text.trim(),
            contact: _contact.text.trim(),
          );
      final created = await ref.read(payersRepoProvider).byId(id);
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = 'Échec : $e';
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
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('NOUVEAU PAYEUR',
                  style: BsType.eyebrow(color: BsColors.sky)),
              const SizedBox(height: 6),
              Text('Société, ONG, particulier tiers',
                  style: BsType.display(18, w: FontWeight.w700)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: RadioListTile<DbPayerType>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: DbPayerType.company,
                    groupValue: _type,
                    onChanged: (v) => setState(() => _type = v!),
                    title: Text('Société',
                        style: BsType.body(12, w: FontWeight.w600)),
                  ),
                ),
                Expanded(
                  child: RadioListTile<DbPayerType>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: DbPayerType.individual,
                    groupValue: _type,
                    onChanged: (v) => setState(() => _type = v!),
                    title: Text('Particulier',
                        style: BsType.body(12, w: FontWeight.w600)),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text('NOM / RAISON SOCIALE', style: BsType.eyebrow()),
              const SizedBox(height: 4),
              TextField(
                controller: _name,
                autofocus: true,
                decoration:
                    const InputDecoration(hintText: 'ex. Afrinvest SARL'),
              ),
              const SizedBox(height: 10),
              Text('NUMÉRO FISCAL / RCCM (optionnel)', style: BsType.eyebrow()),
              const SizedBox(height: 4),
              TextField(
                controller: _taxId,
                decoration: const InputDecoration(hintText: 'ex. CD/LSH/RCCM/'),
              ),
              const SizedBox(height: 10),
              Text('ADRESSE', style: BsType.eyebrow()),
              const SizedBox(height: 4),
              TextField(
                controller: _address,
                minLines: 1,
                maxLines: 2,
                decoration: const InputDecoration(
                    hintText: 'ex. Av. Lumumba, Lubumbashi'),
              ),
              const SizedBox(height: 10),
              Text('CONTACT (email / téléphone)', style: BsType.eyebrow()),
              const SizedBox(height: 4),
              TextField(
                controller: _contact,
                decoration:
                    const InputDecoration(hintText: 'ex. compta@afrinvest.cd'),
              ),
              if (_err != null) ...[
                const SizedBox(height: 10),
                Text(_err!, style: BsType.body(12, color: BsColors.danger)),
              ],
              const SizedBox(height: 16),
              Row(children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
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
                      : const Icon(Icons.check, size: 16),
                  style: FilledButton.styleFrom(backgroundColor: BsColors.sky),
                  onPressed: _busy ? null : _save,
                  label: const Text('Créer'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Saisie d'un **tarif négocié** pour un séjour : prix/nuit consenti à ce
/// client, différent du tarif catalogue de la chambre.
///
/// Le catalogue n'est jamais modifié — l'écart devient une remise visible
/// ligne par ligne sur la facture. Deux façons de saisir :
///   - taper directement le prix négocié en FC ;
///   - cliquer un pourcentage (-5 %, -10 %…) qui calcule le prix.
///
/// `onChanged(null)` quand le tarif catalogue s'applique.
class NegotiatedRateField extends StatefulWidget {
  final int listPriceCents;
  final int? initial;
  final ValueChanged<int?> onChanged;
  final String label;
  const NegotiatedRateField({
    super.key,
    required this.listPriceCents,
    required this.onChanged,
    this.initial,
    this.label = 'TARIF DE LA NUIT',
  });

  @override
  State<NegotiatedRateField> createState() => _NegotiatedRateFieldState();
}

class _NegotiatedRateFieldState extends State<NegotiatedRateField> {
  late bool _on;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _on = widget.initial != null && widget.initial! > 0;
    _ctrl = TextEditingController(text: _on ? widget.initial!.toString() : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int? get _price {
    if (!_on) return null;
    final v = int.tryParse(_ctrl.text.trim().replaceAll(' ', ''));
    return (v == null || v <= 0) ? null : v;
  }

  void _emit() => widget.onChanged(_price);

  void _applyPercent(int hundredths) {
    final p = (widget.listPriceCents * (10000 - hundredths) / 10000).round();
    _ctrl.text = p.toString();
    setState(_emit);
  }

  @override
  Widget build(BuildContext context) {
    final price = _price;
    final saving = price == null ? 0 : widget.listPriceCents - price;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.label, style: BsType.eyebrow()),
        const SizedBox(height: 2),
        Text('Catalogue : ${moneyCents(widget.listPriceCents)} / nuit',
            style: BsType.body(11, color: BsColors.slate)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _on,
          onChanged: (v) => setState(() {
            _on = v;
            if (!v) _ctrl.clear();
            _emit();
          }),
          title: Text('Appliquer un tarif négocié',
              style: BsType.body(12, w: FontWeight.w600)),
        ),
        if (_on) ...[
          Wrap(spacing: 6, children: [
            for (final p in const [500, 1000, 1500, 2000, 2500])
              ActionChip(
                label: Text('-${Discount.formatPercent(p)}',
                    style: BsType.body(11, w: FontWeight.w600)),
                onPressed: () => _applyPercent(p),
              ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(_emit),
            decoration: InputDecoration(
              hintText: '${widget.listPriceCents}',
              suffixText: 'FC / nuit',
              isDense: true,
            ),
          ),
          const SizedBox(height: 6),
          if (price == null)
            Text('Saisis un prix ou repasse au tarif catalogue.',
                style: BsType.body(10, color: BsColors.slateSoft))
          else if (saving > 0)
            Text(
                'Remise de ${moneyCents(saving)} / nuit '
                '(-${Discount.formatPercent((saving * 10000 / widget.listPriceCents).round())}).',
                style: BsType.body(10,
                    w: FontWeight.w600, color: BsColors.success))
          else if (saving < 0)
            Text(
                'Attention : ${moneyCents(-saving)} / nuit AU-DESSUS du tarif catalogue.',
                style:
                    BsType.body(10, w: FontWeight.w700, color: BsColors.danger))
          else
            Text('Identique au tarif catalogue.',
                style: BsType.body(10, color: BsColors.slateSoft)),
        ],
      ],
    );
  }
}
