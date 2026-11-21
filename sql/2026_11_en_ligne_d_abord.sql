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

-- ── Étape 3 : les chambres, validées par le serveur ───────────────────
--
-- Arrivées, départs et changements de statut passent par UNE fonction,
-- qui verrouille les chambres concernées et applique l'opération à toutes
-- d'un coup — ou à aucune. Deux postes ne peuvent plus mettre deux clients
-- dans la même chambre : le second est refusé, avec le nom de l'occupant.
--
-- Chaque opération porte un identifiant créé par le poste : rejouée après
-- une coupure (ou deux fois parce que la réponse s'est perdue), elle ne
-- s'applique qu'une fois.
create table if not exists public.app_operations (
  op_id      text        primary key,
  type       text        not null,
  login      text,
  poste      text,
  resultat   jsonb       not null,
  recu_le    timestamptz not null default now()
);
alter table public.app_operations enable row level security;
revoke all on public.app_operations from anon, authenticated;

-- Statuts : 0 libre, 1 occupée, 2 nettoyage, 3 maintenance.
create or replace function public.bs_chambres_operer(
  p_session  text,
  p_op_id    text,
  p_type     text,      -- 'arrivee' | 'depart' | 'statut'
  p_chambres jsonb,     -- [{number, ...champs}]
  p_poste    text default null
) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare
  u       public.app_users;
  deja    public.app_operations;
  c       jsonb;
  r       public.mirror_rooms;
  numeros text[];
  res     jsonb;
begin
  -- Réception, gérant, super admin.
  u := public.bs_app_exiger(p_session, array[0, 1, 3]::smallint[]);

  if p_op_id is null or length(trim(p_op_id)) = 0 then
    raise exception 'OP_ID_MANQUANT';
  end if;
  select * into deja from public.app_operations where op_id = p_op_id;
  if deja.op_id is not null then
    return deja.resultat::json;
  end if;
  if p_type not in ('arrivee', 'depart', 'statut') then
    raise exception 'OPERATION_INCONNUE';
  end if;

  select array_agg(x->>'number') into numeros
    from jsonb_array_elements(p_chambres) x;
  if numeros is null then
    raise exception 'CHAMBRES_MANQUANTES';
  end if;

  -- Verrou : deux opérations simultanées sur la même chambre se suivent.
  perform 1 from public.mirror_rooms
   where number = any (numeros) order by number for update;

  -- 1. Vérifier TOUTES les chambres avant d'en toucher une.
  for c in select * from jsonb_array_elements(p_chambres) loop
    select * into r from public.mirror_rooms where number = c->>'number';
    if r.number is null then
      res := jsonb_build_object('status', 'refuse', 'motif', 'CHAMBRE_INCONNUE',
                                'chambre', c->>'number');
      exit;
    end if;
    if p_type = 'arrivee' and r.status = 1 then
      res := jsonb_build_object('status', 'refuse', 'motif', 'CHAMBRE_OCCUPEE',
                                'chambre', r.number, 'occupant', r.current_guest);
      exit;
    end if;
    -- Départ : la chambre doit être occupée par CE client (même heure
    -- d'arrivée). Déjà libérée : rien à faire, ce n'est pas une erreur.
    if p_type = 'depart' and r.status = 1
       and r.checkin_at is distinct from (c->>'checkin_at')::timestamptz then
      res := jsonb_build_object('status', 'refuse', 'motif', 'AUTRE_OCCUPANT',
                                'chambre', r.number, 'occupant', r.current_guest);
      exit;
    end if;
    if p_type = 'statut' and r.status = 1 then
      res := jsonb_build_object('status', 'refuse', 'motif', 'CHAMBRE_OCCUPEE',
                                'chambre', r.number, 'occupant', r.current_guest);
      exit;
    end if;
  end loop;

  -- 2. Appliquer, si rien n'a été refusé.
  if res is null then
    for c in select * from jsonb_array_elements(p_chambres) loop
      if p_type = 'arrivee' then
        update public.mirror_rooms set
          status                 = 1,
          current_guest          = c->>'current_guest',
          checkout_date          = (c->>'checkout_date')::timestamptz,
          checkin_note           = c->>'checkin_note',
          checkin_at             = (c->>'checkin_at')::timestamptz,
          stay_group             = c->>'stay_group',
          payer_id               = (c->>'payer_id')::bigint,
          negotiated_price_cents = (c->>'negotiated_price_cents')::bigint
         where number = c->>'number';
      elsif p_type = 'depart' then
        update public.mirror_rooms set
          status = 2, current_guest = null, checkout_date = null,
          checkin_note = null, checkin_at = null, stay_group = null,
          payer_id = null, negotiated_price_cents = null
         where number = c->>'number' and status = 1;
      else
        update public.mirror_rooms set status = (c->>'status')::smallint
         where number = c->>'number';
      end if;
    end loop;
    res := jsonb_build_object('status', 'ok');
  end if;

  -- Un refus aussi est mémorisé : rejoué, il donne la même réponse.
  insert into public.app_operations (op_id, type, login, poste, resultat)
  values (p_op_id, p_type, u.login, p_poste, res);
  return res::json;
end;
$$;

revoke execute on function public.bs_chambres_operer(text, text, text, jsonb, text) from public;
grant execute on function public.bs_chambres_operer(text, text, text, jsonb, text) to anon, authenticated;

notify pgrst, 'reload schema';

commit;

-- ── Vérification ──────────────────────────────────────────────────────
-- select poste, count(*), sum(duree_s)/60 as minutes, max(duree_s)/60 as plus_longue
--   from public.app_coupures where debut > now() - interval '14 days'
--  group by poste;
