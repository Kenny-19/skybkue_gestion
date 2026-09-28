import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/user_error.dart';
import '../../widgets/bs_widgets.dart';
import '../../core/auth.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/schema.dart';
import '../../shell/app_shell.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Écran "Sociétés" — gestion des payeurs tiers (sociétés / particuliers
/// distincts de l'occupant) qui prennent en charge des séjours.
class PayersScreen extends ConsumerStatefulWidget {
  const PayersScreen({super.key});
  @override
  ConsumerState<PayersScreen> createState() => _PayersScreenState();
}

class _PayersScreenState extends ConsumerState<PayersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permsProvider);
    final asyncAll = ref.watch(payersStreamProvider);
    final q = _search.text.trim().toLowerCase();

    return asyncAll.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          BsErrorView(error: handleError(e, st, context: 'payers_screen')),
      data: (all) {
        final list = q.isEmpty
            ? all
            : all.where((p) => p.name.toLowerCase().contains(q)).toList();
        final companies =
            list.where((p) => p.type == DbPayerType.company).length;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                eyebrow: 'Payeurs',
                title: 'Sociétés & tiers',
                subtitle: '${list.length} payeur(s) · $companies société(s)',
                actions: [
                  if (perms.canPayers)
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () => _showEdit(null),
                      label: const Text('Nouveau payeur'),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher…',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: BsSpace.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                child: Container(
                  decoration: BoxDecoration(
                    color: BsColors.paper,
                    borderRadius: BorderRadius.circular(BsRadius.md),
                    border: Border.all(color: BsColors.line),
                  ),
                  child: Column(children: [
                    _headerRow(),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                              q.isEmpty
                                  ? 'Aucun payeur enregistré. Crée-en un depuis le check-in ou ici.'
                                  : 'Aucun résultat.',
                              style: BsType.body(12, color: BsColors.slate)),
                        ),
                      )
                    else
                      for (int i = 0; i < list.length; i++)
                        _PayerRow(
                          payer: list[i],
                          last: i == list.length - 1,
                          canDelete: perms.canDeleteAccounts,
                          onEdit: () => _showEdit(list[i]),
                          onDelete: () => _confirmDelete(list[i]),
                        ),
                  ]),
                ),
              ),
              const SizedBox(height: BsSpace.xxl),
            ],
          ),
        );
      },
    );
  }

  Widget _headerRow() => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: BsSpace.lg, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: BsColors.line)),
        ),
        child: Row(children: [
          Expanded(flex: 4, child: Text('NOM', style: BsType.eyebrow())),
          Expanded(flex: 2, child: Text('TYPE', style: BsType.eyebrow())),
          Expanded(
              flex: 3, child: Text('NUMÉRO FISCAL', style: BsType.eyebrow())),
          Expanded(flex: 3, child: Text('CONTACT', style: BsType.eyebrow())),
          const SizedBox(width: 80),
        ]),
      );

  void _showEdit(Payer? existing) {
    showDialog(
      context: context,
      builder: (_) => _PayerEditDialog(existing: existing),
    );
  }

  Future<void> _confirmDelete(Payer p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: BsColors.paper,
        title: Text('Supprimer ${p.name} ?',
            style: BsType.display(16, w: FontWeight.w700)),
        content: Text(
            'Les chambres actuellement rattachées à ce payeur perdront le lien (facturation redevient au nom de l\'occupant).',
            style: BsType.body(13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BsColors.danger),
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(payersRepoProvider).delete(p.id);
  }
}

class _PayerRow extends StatelessWidget {
  final Payer payer;
  final bool last;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PayerRow({
    required this.payer,
    required this.last,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: BsSpace.lg, vertical: 14),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: BsColors.line)),
        ),
        child: Row(children: [
          Expanded(
            flex: 4,
            child: Row(children: [
              Icon(
                  payer.type == DbPayerType.company
                      ? Icons.business
                      : Icons.person_outline,
                  size: 18,
                  color: BsColors.sky),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(payer.name,
                        style: BsType.body(13, w: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    if (payer.address != null && payer.address!.isNotEmpty)
                      Text(payer.address!,
                          style: BsType.body(11, color: BsColors.slate),
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Text(
                payer.type == DbPayerType.company ? 'Société' : 'Particulier',
                style: BsType.body(12, color: BsColors.slate)),
          ),
          Expanded(
            flex: 3,
            child: Text(payer.taxId ?? '—',
                style: BsType.mono(11, color: BsColors.slate)),
          ),
          Expanded(
            flex: 3,
            child: Text(payer.contact ?? '—',
                style: BsType.body(12, color: BsColors.slate),
                overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                    tooltip: 'Modifier',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16)),
                if (canDelete)
                  IconButton(
                      tooltip: 'Supprimer',
                      onPressed: onDelete,
                      color: BsColors.danger,
                      icon: const Icon(Icons.delete_outline, size: 16)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _PayerEditDialog extends ConsumerStatefulWidget {
  final Payer? existing;
  const _PayerEditDialog({this.existing});
  @override
  ConsumerState<_PayerEditDialog> createState() => _PayerEditDialogState();
}

class _PayerEditDialogState extends ConsumerState<_PayerEditDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _taxId = TextEditingController(text: widget.existing?.taxId ?? '');
  late final _address =
      TextEditingController(text: widget.existing?.address ?? '');
  late final _contact =
      TextEditingController(text: widget.existing?.contact ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late DbPayerType _type = widget.existing?.type ?? DbPayerType.company;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _taxId.dispose();
    _address.dispose();
    _contact.dispose();
    _notes.dispose();
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
      final repo = ref.read(payersRepoProvider);
      if (widget.existing == null) {
        await repo.create(
          name: _name.text.trim(),
          type: _type,
          taxId: _taxId.text.trim(),
          address: _address.text.trim(),
          contact: _contact.text.trim(),
          notes: _notes.text.trim(),
        );
      } else {
        await repo.updateInfo(
          id: widget.existing!.id,
          name: _name.text.trim(),
          type: _type,
          taxId: _taxId.text.trim(),
          address: _address.text.trim(),
          contact: _contact.text.trim(),
          notes: _notes.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
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
    final isEdit = widget.existing != null;
    return Dialog(
      backgroundColor: BsColors.paper,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BsRadius.md)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(isEdit ? 'MODIFIER PAYEUR' : 'NOUVEAU PAYEUR',
                    style: BsType.eyebrow(color: BsColors.sky)),
                const SizedBox(height: 6),
                Text(isEdit ? widget.existing!.name : 'Créer un payeur tiers',
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
                      title: Text('Société', style: BsType.body(12)),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<DbPayerType>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: DbPayerType.individual,
                      groupValue: _type,
                      onChanged: (v) => setState(() => _type = v!),
                      title: Text('Particulier', style: BsType.body(12)),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('NOM / RAISON SOCIALE', style: BsType.eyebrow()),
                const SizedBox(height: 4),
                TextField(controller: _name, autofocus: !isEdit),
                const SizedBox(height: 10),
                Text('NUMÉRO FISCAL / RCCM', style: BsType.eyebrow()),
                const SizedBox(height: 4),
                TextField(controller: _taxId),
                const SizedBox(height: 10),
                Text('ADRESSE', style: BsType.eyebrow()),
                const SizedBox(height: 4),
                TextField(controller: _address, minLines: 1, maxLines: 2),
                const SizedBox(height: 10),
                Text('CONTACT (email / téléphone)', style: BsType.eyebrow()),
                const SizedBox(height: 4),
                TextField(controller: _contact),
                const SizedBox(height: 10),
                Text('NOTES INTERNES', style: BsType.eyebrow()),
                const SizedBox(height: 4),
                TextField(controller: _notes, minLines: 2, maxLines: 3),
                if (_err != null) ...[
                  const SizedBox(height: 10),
                  Text(_err!, style: BsType.body(12, color: BsColors.danger)),
                ],
                const SizedBox(height: 16),
                Row(children: [
                  TextButton(
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Annuler')),
                  const Spacer(),
                  FilledButton.icon(
                    icon: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 16),
                    style:
                        FilledButton.styleFrom(backgroundColor: BsColors.sky),
                    onPressed: _busy ? null : _save,
                    label: Text(isEdit ? 'Enregistrer' : 'Créer'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
