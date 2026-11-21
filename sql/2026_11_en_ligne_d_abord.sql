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

-- ── Étape 2 : un compte par personne, vérifié par le serveur ──────────
--
-- Tout passe désormais par le serveur : il doit savoir QUI agit et avec
-- quels droits. À la connexion en ligne, chaque personne reçoit une
-- session ; chaque opération sensible la présente, et le serveur vérifie
-- le rôle lui-même. La clé publique de l'application ne suffit plus.
--
-- Rôles (mêmes numéros que l'application) : 0 super admin, 1 gérant,
-- 2 serveur, 3 réception.
create table if not exists public.app_sessions (
  -- Le jeton n'est jamais stocké en clair : seulement son empreinte.
  jeton_hash    text        primary key,
  login         text        not null,
  poste         text,
  cree_le       timestamptz not null default now(),
  expire_le     timestamptz not null,
  dernier_usage timestamptz not null default now()
);
create index if not exists app_sessions_expire_idx
  on public.app_sessions (expire_le);
alter table public.app_sessions enable row level security;
revoke all on public.app_sessions from anon, authenticated;

-- Connexion : la vérification habituelle (limite de tentatives comprise),
-- plus une session si elle réussit.
create or replace function public.bs_app_connexion(
  p_login text, p_password text, p_poste text default null
) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare
  r     json;
  jeton text;
begin
  r := public.bs_verify_login(p_login, p_password);
  if r->>'status' <> 'ok' then
    return r;
  end if;
  delete from public.app_sessions where expire_le < now();
  jeton := encode(extensions.gen_random_bytes(32), 'hex');
  insert into public.app_sessions (jeton_hash, login, poste, expire_le)
  values (encode(extensions.digest(jeton, 'sha256'), 'hex'),
          r->'user'->>'login', p_poste, now() + interval '30 days');
  return (r::jsonb || jsonb_build_object('session', jeton))::json;
end;
$$;

-- L'auteur d'une opération, d'après sa session. Interne. Une session
-- d'un compte désactivé ne vaut plus rien, même avant son expiration.
create or replace function public.bs_app_acteur(p_session text)
returns public.app_users
language plpgsql security definer set search_path = public, extensions as $$
declare
  s public.app_sessions;
  u public.app_users;
begin
  select * into s from public.app_sessions
   where jeton_hash = encode(extensions.digest(coalesce(p_session, ''), 'sha256'), 'hex')
     and expire_le > now();
  if s.jeton_hash is null then
    raise exception 'SESSION_INVALIDE';
  end if;
  select * into u from public.app_users
   where lower(login) = lower(s.login) and active;
  if u.id is null then
    raise exception 'SESSION_INVALIDE';
  end if;
  -- Session glissante : trente jours après le dernier usage.
  update public.app_sessions
     set dernier_usage = now(), expire_le = now() + interval '30 days'
   where jeton_hash = s.jeton_hash;
  return u;
end;
$$;

-- Exige l'un des [p_roles]. Interne.
create or replace function public.bs_app_exiger(p_session text, p_roles smallint[])
returns public.app_users
language plpgsql security definer set search_path = public, extensions as $$
declare u public.app_users;
begin
  u := public.bs_app_acteur(p_session);
  if not (u.role = any (p_roles)) then
    raise exception 'DROITS_INSUFFISANTS';
  end if;
  return u;
end;
$$;

create or replace function public.bs_app_deconnexion(p_session text)
returns json
language sql security definer set search_path = public, extensions as $$
  delete from public.app_sessions
   where jeton_hash = encode(extensions.digest(coalesce(p_session, ''), 'sha256'), 'hex');
  select json_build_object('status', 'ok');
$$;

-- Gestion du stock (ravitaillement, correction, stock initial) : gérant
-- ou super admin, vérifié ICI. Les sorties des ventes, elles, restent sur
-- bs_adjust_stock_uid.
create or replace function public.bs_stock_gerer(
  p_session     text,
  p_op_id       text,
  p_article_uid uuid,
  p_delta       int,
  p_reason      text default null,
  p_poste       text default null
) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare u public.app_users;
begin
  u := public.bs_app_exiger(p_session, array[0, 1]::smallint[]);
  return public.bs_adjust_stock_uid(
    p_op_id, p_article_uid, p_delta,
    coalesce(p_reason, 'gestion') || ' (' || u.login || ')', p_poste);
end;
$$;

revoke execute on function public.bs_app_acteur(text) from public, anon, authenticated;
revoke execute on function public.bs_app_exiger(text, smallint[]) from public, anon, authenticated;
revoke execute on function public.bs_app_connexion(text, text, text) from public;
revoke execute on function public.bs_app_deconnexion(text) from public;
revoke execute on function public.bs_stock_gerer(text, text, uuid, int, text, text) from public;
grant execute on function public.bs_app_connexion(text, text, text) to anon, authenticated;
grant execute on function public.bs_app_deconnexion(text) to anon, authenticated;
grant execute on function public.bs_stock_gerer(text, text, uuid, int, text, text) to anon, authenticated;

notify pgrst, 'reload schema';

commit;

-- ── Vérification ──────────────────────────────────────────────────────
-- select poste, count(*), sum(duree_s)/60 as minutes, max(duree_s)/60 as plus_longue
--   from public.app_coupures where debut > now() - interval '14 days'
--  group by poste;
