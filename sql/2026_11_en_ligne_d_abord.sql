-- =====================================================================
-- EN LIGNE D'ABORD — le serveur fait foi, le poste prend le relais
-- pendant les coupures.
-- =====================================================================
--
-- Un seul script pour tout le chantier, complété à chaque étape. À
-- EXÉCUTER UNE FOIS dans Supabase → SQL Editor, AVANT de publier la
-- version qui l'utilise. Rejouable.
-- =====================================================================

begin;

-- ── Étape 1 : les coupures ────────────────────────────────────────────
--
-- Combien de temps les postes passent-ils sans réseau ? On ne le savait
-- pas : l'ancien code abandonnait ce qui était fait pendant une coupure,
-- et ce qui n'arrivait jamais ne laissait aucune trace. Chaque poste
-- mesure désormais ses coupures et les envoie au retour du réseau.
create table if not exists public.app_coupures (
  id        bigserial   primary key,
  poste     text        not null,
  debut     timestamptz not null,
  fin       timestamptz not null,
  duree_s   integer     generated always as
              (extract(epoch from (fin - debut))::integer) stored,
  recu_le   timestamptz not null default now()
);
create index if not exists app_coupures_debut_idx
  on public.app_coupures (debut desc);

-- Les postes écrivent, ils ne lisent pas (même principe qu'error_logs).
alter table public.app_coupures enable row level security;
revoke all on public.app_coupures from anon, authenticated;
grant insert on public.app_coupures to anon, authenticated;
grant usage, select on sequence public.app_coupures_id_seq to anon, authenticated;
drop policy if exists app_coupures_insertion on public.app_coupures;
create policy app_coupures_insertion on public.app_coupures
  for insert to anon, authenticated with check (fin >= debut);

notify pgrst, 'reload schema';

commit;

-- ── Vérification ──────────────────────────────────────────────────────
-- select poste, count(*), sum(duree_s)/60 as minutes, max(duree_s)/60 as plus_longue
--   from public.app_coupures where debut > now() - interval '14 days'
--  group by poste;
