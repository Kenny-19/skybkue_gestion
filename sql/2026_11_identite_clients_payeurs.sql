-- =====================================================================
-- IDENTITÉ DES CLIENTS, DES PAYEURS ET DES RÉSERVATIONS
-- =====================================================================
--
-- Constat (27 octobre 2026, toujours vrai le 21 novembre) : `mirror_clients.id` et `mirror_payers.id`
-- sont les numéros LOCAUX du poste qui a envoyé la fiche. Le client n° 5
-- de la réception et le client n° 5 de la caisse sont la même ligne pour
-- le serveur : le dernier envoyé écrase l'autre. Même défaut que les
-- ventes avant octobre. Et `mirror_rooms.payer_id` désigne une société
-- par ce numéro local : lu sur un autre poste, il peut nommer une autre
-- société.
--
-- Mesuré ce jour : 136 clients (134 sans téléphone, 2 noms en double),
-- 23 payeurs (4 noms en double), 11 chambres rattachées à un payeur.
--
-- La correction, sur le modèle des articles :
--   * chaque fiche porte un `uid` DÉDUIT de ce qui l'identifiait déjà
--     pour les postes :
--       client : md5('C|T|' || btrim(phone))                si téléphone
--                md5('C|N|' || minuscules(btrim(full_name))) sinon
--       payeur : md5('P|' || minuscules(btrim(name)))
--     « minuscules » suit une table EXPLICITE (A-Z et les majuscules
--     accentuées du français) plutôt que `lower()`, qui dépend des
--     réglages du serveur : l'application applique la même table, au
--     caractère près (lib/core/identite.dart) ;
--   * les doublons sont FUSIONNÉS (compteurs : le plus grand, comme le
--     font déjà les postes) ; les fiches retirées sont archivées dans
--     `app_fusion_fiches` ;
--   * les numéros existants passent au-dessus de 1 000 000, comme les
--     nouveaux : un poste pas encore à jour qui envoie « le client n° 5 »
--     ne peut plus écraser une autre personne. Si la personne existe
--     déjà, son envoi est refusé au lieu de créer un doublon ;
--   * les chambres désignent leur payeur par `payer_uid` ;
--   * les réservations reçoivent leurs colonnes d'identité, pour leur
--     future synchronisation.
--
-- À EXÉCUTER UNE FOIS dans Supabase → SQL Editor, AVANT de publier la
-- version qui envoie les fiches par uid. Rejouable.
-- =====================================================================

begin;

-- ── 1. Formules d'identité ────────────────────────────────────────────
create or replace function public.bs_minuscules(t text)
returns text language sql immutable as $$
  -- ⚠️ Même table que _minuscules() dans lib/core/identite.dart.
  select translate(t,
    'ABCDEFGHIJKLMNOPQRSTUVWXYZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ',
    'abcdefghijklmnopqrstuvwxyzàáâãäåçèéêëìíîïñòóôõöùúûüý')
$$;

-- ⚠️ Mêmes formules que uidClient() / uidPayeur() dans l'application.
create or replace function public.bs_uid_client(p_nom text, p_tel text)
returns uuid language sql immutable as $$
  select case
    when nullif(btrim(coalesce(p_tel, '')), '') is not null
      then md5('C|T|' || btrim(p_tel))::uuid
    else md5('C|N|' || public.bs_minuscules(btrim(p_nom)))::uuid
  end
$$;

create or replace function public.bs_uid_payeur(p_nom text)
returns uuid language sql immutable as $$
  select md5('P|' || public.bs_minuscules(btrim(p_nom)))::uuid
$$;

-- ── 2. Colonnes ───────────────────────────────────────────────────────
alter table public.mirror_clients add column if not exists uid uuid;
alter table public.mirror_payers  add column if not exists uid uuid;
alter table public.mirror_rooms   add column if not exists payer_uid uuid;

update public.mirror_clients set uid = public.bs_uid_client(full_name, phone)
 where uid is null;
update public.mirror_payers set uid = public.bs_uid_payeur(name)
 where uid is null;

-- La chambre garde le payeur que son `payer_id` désignait SUR LE SERVEUR.
-- C'est la meilleure lecture disponible ; un poste à jour la corrige au
-- prochain envoi de la chambre.
update public.mirror_rooms r
   set payer_uid = p.uid
  from public.mirror_payers p
 where p.id = r.payer_id
   and r.payer_uid is null;

-- ── 3. Journal des fusions ────────────────────────────────────────────
create table if not exists public.app_fusion_fiches (
  table_name   text        not null,
  ancien_id    bigint      not null,
  garde_id     bigint      not null,
  uid          uuid        not null,
  ligne        jsonb       not null,
  fusionne_le  timestamptz not null default now(),
  primary key (table_name, ancien_id)
);
alter table public.app_fusion_fiches enable row level security;
revoke all on public.app_fusion_fiches from anon, authenticated;

-- ── 4. Fusion des clients en double ───────────────────────────────────
create temporary table _clients on commit drop as
select id, uid,
       first_value(id) over (
         partition by uid
         order by (phone is not null) desc, visits_count desc, id asc
       ) as garde_id
  from public.mirror_clients;

update public.mirror_clients g
   set visits_count      = s.visites,
       total_spent_cents = s.depense,
       first_seen_at     = s.premiere,
       last_seen_at      = s.derniere,
       email             = coalesce(g.email, s.email),
       notes             = coalesce(g.notes, s.notes)
  from (
    select c.garde_id,
           max(m.visits_count)      as visites,
           max(m.total_spent_cents) as depense,
           min(m.first_seen_at)     as premiere,
           max(m.last_seen_at)      as derniere,
           max(m.email)             as email,
           max(m.notes)             as notes
      from _clients c
      join public.mirror_clients m on m.id = c.id
     group by c.garde_id
    having count(*) > 1
  ) s
 where g.id = s.garde_id;

insert into public.app_fusion_fiches (table_name, ancien_id, garde_id, uid, ligne)
select 'mirror_clients', m.id, c.garde_id, m.uid, to_jsonb(m)
  from public.mirror_clients m
  join _clients c on c.id = m.id
 where c.id <> c.garde_id
on conflict do nothing;

delete from public.mirror_clients m
 using _clients c
 where c.id = m.id and c.id <> c.garde_id;

-- ── 5. Fusion des payeurs en double ───────────────────────────────────
-- Gardée : la fiche la plus renseignée (NIF, adresse, contact).
create temporary table _payeurs on commit drop as
select id, uid,
       first_value(id) over (
         partition by uid
         order by ((tax_id is not null)::int + (address is not null)::int
                   + (contact is not null)::int) desc,
                  id asc
       ) as garde_id
  from public.mirror_payers;

update public.mirror_payers g
   set tax_id  = coalesce(g.tax_id,  s.tax_id),
       address = coalesce(g.address, s.address),
       contact = coalesce(g.contact, s.contact),
       notes   = coalesce(g.notes,   s.notes)
  from (
    select p.garde_id,
           max(m.tax_id) as tax_id, max(m.address) as address,
           max(m.contact) as contact, max(m.notes) as notes
      from _payeurs p
      join public.mirror_payers m on m.id = p.id
     group by p.garde_id
    having count(*) > 1
  ) s
 where g.id = s.garde_id;

insert into public.app_fusion_fiches (table_name, ancien_id, garde_id, uid, ligne)
select 'mirror_payers', m.id, p.garde_id, m.uid, to_jsonb(m)
  from public.mirror_payers m
  join _payeurs p on p.id = m.id
 where p.id <> p.garde_id
on conflict do nothing;

delete from public.mirror_payers m
 using _payeurs p
 where p.id = m.id and p.id <> p.garde_id;

-- ── 6. Unicité, numéros serveur ───────────────────────────────────────
create unique index if not exists mirror_clients_uid_key
  on public.mirror_clients (uid);
create unique index if not exists mirror_payers_uid_key
  on public.mirror_payers (uid);

-- Les numéros hérités des postes passent au-dessus de 1 000 000.
update public.mirror_clients set id = id + 1000000 where id < 1000000;
update public.mirror_payers  set id = id + 1000000 where id < 1000000;

create sequence if not exists public.mirror_clients_id_seq start with 1000000;
alter sequence public.mirror_clients_id_seq owned by public.mirror_clients.id;
select setval('public.mirror_clients_id_seq',
  greatest(1000000, (select coalesce(max(id), 0) from public.mirror_clients)));
alter table public.mirror_clients
  alter column id set default nextval('public.mirror_clients_id_seq');

create sequence if not exists public.mirror_payers_id_seq start with 1000000;
alter sequence public.mirror_payers_id_seq owned by public.mirror_payers.id;
select setval('public.mirror_payers_id_seq',
  greatest(1000000, (select coalesce(max(id), 0) from public.mirror_payers)));
alter table public.mirror_payers
  alter column id set default nextval('public.mirror_payers_id_seq');

grant usage, select on sequence public.mirror_clients_id_seq,
  public.mirror_payers_id_seq to anon, authenticated;

-- Postes pas encore à jour : ils envoient sans uid. On le calcule ; si la
-- personne existe déjà, l'insertion échoue au lieu de créer un doublon.
create or replace function public.bs_mirror_clients_identite()
returns trigger language plpgsql as $$
begin
  if new.uid is null then
    new.uid := public.bs_uid_client(new.full_name, new.phone);
  end if;
  return new;
end;
$$;
drop trigger if exists mirror_clients_identite on public.mirror_clients;
create trigger mirror_clients_identite
  before insert on public.mirror_clients
  for each row execute function public.bs_mirror_clients_identite();

create or replace function public.bs_mirror_payers_identite()
returns trigger language plpgsql as $$
begin
  if new.uid is null then
    new.uid := public.bs_uid_payeur(new.name);
  end if;
  return new;
end;
$$;
drop trigger if exists mirror_payers_identite on public.mirror_payers;
create trigger mirror_payers_identite
  before insert on public.mirror_payers
  for each row execute function public.bs_mirror_payers_identite();

alter table public.mirror_clients alter column uid set not null;
alter table public.mirror_payers  alter column uid set not null;

-- Un poste pas encore à jour change le payeur d'une chambre sans donner
-- son uid : on l'oublie plutôt que de garder l'ancien, qui serait faux.
create or replace function public.bs_mirror_rooms_payeur()
returns trigger language plpgsql as $$
begin
  if new.payer_id is null then
    new.payer_uid := null;
  elsif tg_op = 'UPDATE'
     and new.payer_id is distinct from old.payer_id
     and new.payer_uid is not distinct from old.payer_uid then
    new.payer_uid := null;
  end if;
  return new;
end;
$$;
drop trigger if exists mirror_rooms_payeur on public.mirror_rooms;
create trigger mirror_rooms_payeur
  before insert or update on public.mirror_rooms
  for each row execute function public.bs_mirror_rooms_payeur();

-- ── 7. Réservations : colonnes d'identité ─────────────────────────────
alter table public.mirror_reservations
  add column if not exists uid uuid,
  add column if not exists payer_uid uuid,
  add column if not exists poste text;
alter table public.mirror_reservation_rooms
  add column if not exists uid uuid,
  add column if not exists reservation_uid uuid;
create unique index if not exists mirror_reservations_uid_key
  on public.mirror_reservations (uid);
create unique index if not exists mirror_reservation_rooms_uid_key
  on public.mirror_reservation_rooms (uid);

notify pgrst, 'reload schema';

commit;

-- ── Vérification ──────────────────────────────────────────────────────
-- select count(*), count(distinct uid), min(id) from public.mirror_clients;
--   -- 134 / 134 / > 1000000 attendus
-- select count(*), count(distinct uid), min(id) from public.mirror_payers;
--   -- 19 / 19 / > 1000000 attendus
-- select count(*) from public.mirror_rooms where payer_id is not null
--    and payer_uid is null;  -- 0 attendu
