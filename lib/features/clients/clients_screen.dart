import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/user_error.dart';
import '../../widgets/bs_widgets.dart';
import '../../core/auth.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../shell/app_shell.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../core/temps.dart';

/// Fichier client / fidélité.
///
/// - Liste triable par dernière visite, séjours, dépenses.
/// - Filtre par nom / téléphone.
/// - Fiche client détaillée en dialog (édition + suppression super admin).
class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});
  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

enum _SortBy { lastSeen, visits, spent, name }

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _search = TextEditingController();
  _SortBy _sort = _SortBy.lastSeen;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permsProvider);
    final asyncAll = ref.watch(clientsStreamProvider);
    final q = _search.text.trim().toLowerCase();

    return asyncAll.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          BsErrorView(error: handleError(e, st, context: 'clients_screen')),
      data: (all) {
        List<Client> list = q.isEmpty
            ? [...all]
            : all.where((c) {
                return c.fullName.toLowerCase().contains(q) ||
                    (c.phone ?? '').toLowerCase().contains(q);
              }).toList();
        _sortList(list);

        final loyal = list.where((c) => c.visitsCount >= 2).length;
        final totalSpent = list.fold<int>(0, (s, c) => s + c.totalSpentCents);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                eyebrow: 'Fidélité',
                title: 'Fichier client',
                subtitle:
                    '${list.length} client(s) · $loyal fidèle(s) · dépensé total ${moneyCents(totalSpent)}',
                actions: const [],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BsSpace.xl),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher (nom ou téléphone)…',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<_SortBy>(
                    value: _sort,
                    onChanged: (v) => setState(() => _sort = v!),
                    items: const [
                      DropdownMenuItem(
                          value: _SortBy.lastSeen,
                          child: Text('Dernière visite')),
                      DropdownMenuItem(
                          value: _SortBy.visits, child: Text('Nb séjours')),
                      DropdownMenuItem(
                          value: _SortBy.spent, child: Text('Dépenses')),
                      DropdownMenuItem(
                          value: _SortBy.name, child: Text('Nom (A→Z)')),
                    ],
                  ),
                ]),
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
                                  ? 'Aucun client enregistré. Fais un check-in ou une vente POS pour créer le premier.'
                                  : 'Aucun résultat pour « ${_search.text} ».',
                              style: BsType.body(12, color: BsColors.slate)),
                        ),
                      )
                    else
                      for (int i = 0; i < list.length; i++)
                        _ClientRow(
                          client: list[i],
                          last: i == list.length - 1,
                          canDelete: perms.canDeleteAccounts,
                          onOpen: () => _openDetail(list[i]),
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

  void _sortList(List<Client> list) {
    switch (_sort) {
      case _SortBy.lastSeen:
        list.sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
        break;
      case _SortBy.visits:
        list.sort((a, b) => b.visitsCount.compareTo(a.visitsCount));
        break;
      case _SortBy.spent:
        list.sort((a, b) => b.totalSpentCents.compareTo(a.totalSpentCents));
        break;
      case _SortBy.name:
        list.sort((a, b) =>
            a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
        break;
    }
  }

  Widget _headerRow() => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: BsSpace.lg, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: BsColors.line)),
        ),
        child: Row(children: [
          Expanded(flex: 4, child: Text('CLIENT', style: BsType.eyebrow())),
          Expanded(flex: 3, child: Text('TÉLÉPHONE', style: BsType.eyebrow())),
          Expanded(flex: 2, child: Text('SÉJOURS', style: BsType.eyebrow())),
          Expanded(flex: 2, child: Text('DÉPENSÉ', style: BsType.eyebrow())),
          Expanded(
              flex: 3, child: Text('DERNIÈRE VISITE', style: BsType.eyebrow())),
          const SizedBox(width: 80),
        ]),
      );

  void _openDetail(Client c) {
    showDialog(
      context: context,
      builder: (_) => _ClientEditDialog(client: c),
    );
  }

  Future<void> _confirmDelete(Client c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: BsColors.paper,
        title: Text('Supprimer ${c.fullName} ?',
            style: BsType.display(16, w: FontWeight.w700)),
        content: Text(
            'Cette action supprime définitivement le client de la BDD locale ET du miroir cloud. Son historique de séjours (chambres, factures) reste intact.',
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
    await ref.read(clientsRepoProvider).delete(c.id);
  }
}

class _ClientRow extends StatelessWidget {
  final Client client;
  final bool last;
  final bool canDelete;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  const _ClientRow({
    required this.client,
    required this.last,
    required this.canDelete,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final loyal = client.visitsCount >= 2;
    return InkWell(
      onTap: onOpen,
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (loyal ? BsColors.success : BsColors.slate)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                    client.fullName.isEmpty
                        ? '?'
                        : client.fullName.substring(0, 1).toUpperCase(),
                    style: BsType.body(12,
                        w: FontWeight.w700,
                        color: loyal ? BsColors.success : BsColors.slate)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.fullName,
                        style: BsType.body(13, w: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    if (loyal)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: BsColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text('FIDÈLE',
                            style: BsType.body(9,
                                w: FontWeight.w800, color: BsColors.success)),
                      ),
                  ],
                ),
              ),
            ]),
          ),
          Expanded(
            flex: 3,
            child: Text(client.phone ?? '—',
                style: BsType.mono(12, color: BsColors.slate)),
          ),
          Expanded(
            flex: 2,
            child: Text('${client.visitsCount}',
                style: BsType.body(13, w: FontWeight.w600)),
          ),
          Expanded(
            flex: 2,
            child: Text(moneyCents(client.totalSpentCents),
                style: BsType.body(12, w: FontWeight.w600)),
          ),
          Expanded(
            flex: 3,
            child: Text(
                DateFormat("d MMM y", 'fr_FR')
                    .format(aLubumbashi(client.lastSeenAt)),
                style: BsType.body(12, color: BsColors.slate)),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                    tooltip: 'Fiche',
                    onPressed: onOpen,
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

class _ClientEditDialog extends ConsumerStatefulWidget {
  final Client client;
  const _ClientEditDialog({required this.client});
  @override
  ConsumerState<_ClientEditDialog> createState() => _ClientEditDialogState();
}

class _ClientEditDialogState extends ConsumerState<_ClientEditDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.client.fullName);
  late final TextEditingController _phone =
      TextEditingController(text: widget.client.phone ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.client.email ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.client.notes ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    return Dialog(
      backgroundColor: BsColors.paper,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BsRadius.md)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('FICHE CLIENT',
                    style: BsType.eyebrow(color: BsColors.sunrise)),
                const SizedBox(height: 6),
                Text(c.fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BsType.display(20, w: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(children: [
                  _kpi('SÉJOURS', '${c.visitsCount}'),
                  const SizedBox(width: 12),
                  _kpi('DÉPENSÉ', moneyCents(c.totalSpentCents)),
                  const SizedBox(width: 12),
                  _kpi(
                      'DEPUIS',
                      DateFormat("d MMM y", 'fr_FR')
                          .format(aLubumbashi(c.firstSeenAt))),
                ]),
                const SizedBox(height: 16),
                Text('NOM COMPLET', style: BsType.eyebrow()),
                const SizedBox(height: 4),
                TextField(controller: _name),
                const SizedBox(height: 10),
                Text('TÉLÉPHONE', style: BsType.eyebrow()),
                const SizedBox(height: 4),
                TextField(
                    controller: _phone, keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                Text('EMAIL', style: BsType.eyebrow()),
                const SizedBox(height: 4),
                TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 10),
                Text('NOTES INTERNES', style: BsType.eyebrow()),
                const SizedBox(height: 4),
                TextField(
                    controller: _notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        hintText:
                            'Préférences, allergies, historique particulier…')),
                const SizedBox(height: 16),
                Row(children: [
                  TextButton(
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Fermer')),
                  const Spacer(),
                  FilledButton.icon(
                    icon: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 16),
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            await ref.read(clientsRepoProvider).updateInfo(
                                  id: c.id,
                                  fullName: _name.text.trim(),
                                  phone: _phone.text.trim(),
                                  email: _email.text.trim(),
                                  notes: _notes.text.trim(),
                                );
                            if (!mounted) return;
                            Navigator.of(context).pop();
                          },
                    label: const Text('Enregistrer'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kpi(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: BsColors.inkSoft.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(BsRadius.sm),
            border: Border.all(color: BsColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: BsType.eyebrow()),
              const SizedBox(height: 2),
              Text(value,
                  style: BsType.body(13, w: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}
