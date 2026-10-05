-- =====================================================================
-- IDENTITÉ DES SÉJOURS — même correction que pour les ventes
-- =====================================================================
--
-- `mirror_stays.id` était le compteur LOCAL du poste qui a fait le
-- départ. Deux postes produisaient donc des séjours de même numéro, et
-- le dernier envoyé écrasait l'autre — facture comprise. Même chose pour
-- les chambres des séjours.
--
-- Même schéma que sql/2026_10_identite_ventes.sql :
--   * `uid` sur chaque séjour et chaque chambre de séjour, créé par le
--     poste : c'est la clé de synchronisation (application 0.0.30+) ;
--   * `id` devient un compteur du SERVEUR pour les nouveaux séjours ; les
--     chambres continuent de pointer sur `mirror_stays.id` ;
--   * `numero_local` et `poste` gardent l'origine.
--
-- Uid des séjours déjà présents, formule identique à l'application
-- (uidSejourHerite, lib/core/identite.dart) :
--   md5('S|' || id || '|' || epoch(checkout_at))
--
-- À EXÉCUTER UNE FOIS, dans Supabase → SQL Editor, AVANT de publier la
-- version qui contient le séjour dès l'arrivée. Rejouable.
-- =====================================================================

begin;

alter table public.mirror_stays      add column if not exists uid          uuid;
alter table public.mirror_stays      add column if not exists numero_local bigint;
alter table public.mirror_stays      add column if not exists poste        text;
alter table public.mirror_stay_rooms add column if not exists uid          uuid;

update public.mirror_stays
   set uid = md5('S|' || id::text || '|'
                 || floor(extract(epoch from checkout_at))::bigint::text)::uuid
 where uid is null;

update public.mirror_stays
   set numero_local = id
 where numero_local is null;

update public.mirror_stay_rooms r
   set uid = md5(s.uid::text || '|' || r.id::text)::uuid
  from public.mirror_stays s
 where s.id = r.stay_id
   and r.uid is null;

create unique index if not exists mirror_stays_uid_key
  on public.mirror_stays (uid);
create unique index if not exists mirror_stay_rooms_uid_key
  on public.mirror_stay_rooms (uid);

create sequence if not exists public.mirror_stays_id_seq start with 1000000;
create sequence if not exists public.mirror_stay_rooms_id_seq start with 1000000;
alter sequence public.mirror_stays_id_seq owned by public.mirror_stays.id;
alter sequence public.mirror_stay_rooms_id_seq owned by public.mirror_stay_rooms.id;
alter table public.mirror_stays
  alter column id set default nextval('public.mirror_stays_id_seq');
alter table public.mirror_stay_rooms
  alter column id set default nextval('public.mirror_stay_rooms_id_seq');

grant usage, select on sequence public.mirror_stays_id_seq      to anon, authenticated;
grant usage, select on sequence public.mirror_stay_rooms_id_seq to anon, authenticated;

-- Postes pas encore mis à jour : ils envoient encore leur numéro local,
-- sans uid. Même logique que pour les ventes.
create or replace function public.bs_mirror_stays_identite()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if new.uid is null then
      new.uid := md5('S|' || new.id::text || '|'
                     || floor(extract(epoch from new.checkout_at))::bigint::text)::uuid;
    end if;
  elsif new.id < 1000000
        and new.checkout_at is distinct from old.checkout_at
        and new.uid is not distinct from old.uid then
    -- Un autre séjour de même numéro vient d'écraser celui-ci : l'uid
    -- suit le contenu.
    new.uid := md5('S|' || new.id::text || '|'
                   || floor(extract(epoch from new.checkout_at))::bigint::text)::uuid;
  end if;
  if new.numero_local is null then
    new.numero_local := new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists mirror_stays_identite on public.mirror_stays;
create trigger mirror_stays_identite
  before insert or update on public.mirror_stays
  for each row execute function public.bs_mirror_stays_identite();

create or replace function public.bs_mirror_stay_rooms_identite()
returns trigger
language plpgsql
as $$
begin
  if new.uid is null then
    select md5(s.uid::text || '|' || new.id::text)::uuid
      into new.uid
      from public.mirror_stays s
     where s.id = new.stay_id;
    new.uid := coalesce(new.uid, gen_random_uuid());
  end if;
  return new;
end;
$$;

drop trigger if exists mirror_stay_rooms_identite on public.mirror_stay_rooms;
create trigger mirror_stay_rooms_identite
  before insert on public.mirror_stay_rooms
  for each row execute function public.bs_mirror_stay_rooms_identite();

alter table public.mirror_stays      alter column uid set not null;
alter table public.mirror_stay_rooms alter column uid set not null;

notify pgrst, 'reload schema';

commit;

-- ── Vérification ──────────────────────────────────────────────────────
-- select count(*) as sejours, count(distinct uid) as identites
--   from public.mirror_stays;
-- Les deux nombres doivent être égaux.
