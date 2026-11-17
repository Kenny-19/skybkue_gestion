-- =====================================================================
-- SYNCHRONISATION PAR DIFFÉRENCE
-- =====================================================================
--
-- Constat (17 novembre 2026) : toutes les quinze secondes, CHAQUE poste
-- relit en entier les chambres, les clients, les payeurs, le catalogue
-- et les 500 derniers séjours — même quand rien n'a bougé. Le trafic
-- grandit avec le nombre de postes ET avec l'historique, sans limite.
-- Mesuré : 111 Ko par tour, environ 630 Mo par jour et par poste.
--
-- La correction :
--   * chaque table relue par les postes porte `updated_at`, posé par le
--     serveur à chaque VRAIE modification. Un envoi identique (les postes
--     renvoient tout leur catalogue toutes les dix minutes) ne le bouge
--     pas : sinon chaque renvoi ferait tout retélécharger aux autres ;
--   * `bs_versions()` rend, en une seule petite réponse, la dernière
--     modification de chaque table. Le poste ne relit une table que si
--     elle a changé, et seulement les lignes modifiées depuis son dernier
--     passage ;
--   * pour les chambres, le nombre de lignes aussi : une suppression ne
--     laisse pas de date, mais elle change le compte.
--
-- Les postes pas encore à jour continuent de tout relire, comme avant.
--
-- À EXÉCUTER une fois dans Supabase → SQL Editor, AVANT de publier la
-- version qui lit les changements par différence. Rejouable.
-- =====================================================================

begin;

create or replace function public.bs_marquer_modification()
returns trigger language plpgsql as $$
begin
  -- `synced_at` est réécrit par chaque envoi : il n'est pas un changement.
  if tg_op = 'UPDATE'
     and (to_jsonb(new) - 'updated_at' - 'synced_at')
       = (to_jsonb(old) - 'updated_at' - 'synced_at') then
    new.updated_at := old.updated_at;
  else
    new.updated_at := clock_timestamp();
  end if;
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array['mirror_rooms', 'mirror_clients', 'mirror_payers',
                           'mirror_articles', 'mirror_stays']
  loop
    execute format(
      'alter table public.%I add column if not exists updated_at timestamptz '
      'not null default clock_timestamp()', t);
    execute format(
      'create index if not exists %I on public.%I (updated_at)',
      t || '_updated_at_idx', t);
    execute format('drop trigger if exists %I on public.%I',
      t || '_modification', t);
    execute format(
      'create trigger %I before insert or update on public.%I '
      'for each row execute function public.bs_marquer_modification()',
      t || '_modification', t);
  end loop;
end;
$$;

-- Une seule petite réponse pour savoir ce qui a bougé.
create or replace function public.bs_versions()
returns json language sql stable set search_path = public as $$
  select json_build_object(
    'rooms', json_build_object(
       'max', (select max(updated_at) from public.mirror_rooms),
       'nb',  (select count(*)        from public.mirror_rooms)),
    'clients',  (select max(updated_at) from public.mirror_clients),
    'payers',   (select max(updated_at) from public.mirror_payers),
    'articles', (select max(updated_at) from public.mirror_articles),
    'stays',    (select max(updated_at) from public.mirror_stays)
  )
$$;
revoke execute on function public.bs_versions() from public;
grant execute on function public.bs_versions() to anon, authenticated;

notify pgrst, 'reload schema';

commit;

-- ── Vérification ──────────────────────────────────────────────────────
-- select public.bs_versions();
