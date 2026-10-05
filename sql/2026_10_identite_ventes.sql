-- =====================================================================
-- IDENTITÉ DES VENTES — une vente garde son identité sur tous les postes
-- =====================================================================
--
-- Le problème
-- -----------
-- `mirror_sales.id` était le compteur LOCAL du poste qui a encaissé. La
-- vente n° 345 de la caisse et la vente n° 345 de la réception étaient la
-- même ligne ici : la dernière envoyée écrasait l'autre. Même chose pour
-- les lignes de vente.
--
-- La correction
-- -------------
--   * chaque vente et chaque ligne portent un `uid`, créé par le poste ;
--     c'est la clé de synchronisation (application 0.0.29 et suivantes) ;
--   * `id` devient un compteur du SERVEUR pour les nouvelles ventes. Les
--     lignes continuent de pointer sur `mirror_sales.id` : le portail, le
--     tableau de bord et les requêtes d'encours n'ont pas à changer ;
--   * `numero_local` garde le numéro du ticket, `poste` le poste d'origine.
--
-- Les lignes déjà présentes reçoivent un uid DÉDUIT de leur numéro et de
-- leur heure de vente, avec la formule exacte de l'application
-- (lib/core/identite.dart). Chaque poste calcule le même pour ses ventes :
-- les deux se retrouvent sans échange.
--
-- À EXÉCUTER UNE FOIS, dans Supabase → SQL Editor, AVANT de publier la
-- version 0.0.29. Rejouable sans effet de bord.
-- =====================================================================

begin;

-- ── 1. Colonnes ───────────────────────────────────────────────────────
alter table public.mirror_sales      add column if not exists uid          uuid;
alter table public.mirror_sales      add column if not exists numero_local bigint;
alter table public.mirror_sales      add column if not exists poste        text;
alter table public.mirror_sale_lines add column if not exists uid          uuid;

-- ── 2. Identité des lignes déjà présentes ─────────────────────────────
-- ⚠️ Même formule que uidVenteHerite() dans l'application.
update public.mirror_sales
   set uid = md5(id::text || '|'
                 || floor(extract(epoch from sold_at))::bigint::text)::uuid
 where uid is null;

update public.mirror_sales
   set numero_local = id
 where numero_local is null;

-- ⚠️ Même formule que uidLigneHerite().
update public.mirror_sale_lines l
   set uid = md5(s.uid::text || '|' || l.id::text)::uuid
  from public.mirror_sales s
 where s.id = l.sale_id
   and l.uid is null;

-- ── 3. Unicité ────────────────────────────────────────────────────────
-- Index unique (et non contrainte) : c'est ce que `on conflict (uid)` de
-- l'application vient chercher.
create unique index if not exists mirror_sales_uid_key
  on public.mirror_sales (uid);
create unique index if not exists mirror_sale_lines_uid_key
  on public.mirror_sale_lines (uid);

-- ── 4. Le serveur numérote les nouvelles ventes ───────────────────────
-- À partir d'un million : les numéros locaux des postes restent loin en
-- dessous, et une ancienne version (qui envoie encore son numéro local)
-- ne peut pas tomber sur une vente numérotée ici.
create sequence if not exists public.mirror_sales_id_seq start with 1000000;
create sequence if not exists public.mirror_sale_lines_id_seq start with 1000000;
alter sequence public.mirror_sales_id_seq owned by public.mirror_sales.id;
alter sequence public.mirror_sale_lines_id_seq owned by public.mirror_sale_lines.id;
alter table public.mirror_sales
  alter column id set default nextval('public.mirror_sales_id_seq');
alter table public.mirror_sale_lines
  alter column id set default nextval('public.mirror_sale_lines_id_seq');

-- Sans ce droit, l'application (clé anon) ne peut pas tirer un numéro et
-- toute nouvelle vente serait refusée.
grant usage, select on sequence public.mirror_sales_id_seq      to anon, authenticated;
grant usage, select on sequence public.mirror_sale_lines_id_seq to anon, authenticated;

-- ── 5. Postes pas encore mis à jour ───────────────────────────────────
-- Une version 0.0.28 ou antérieure envoie encore ses ventes sans uid, avec
-- son numéro local. Ces déclencheurs leur donnent l'uid que le poste
-- calculera lui-même après sa mise à jour.
create or replace function public.bs_mirror_sales_identite()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if new.uid is null then
      new.uid := md5(new.id::text || '|'
                     || floor(extract(epoch from new.sold_at))::bigint::text)::uuid;
    end if;
  elsif new.id < 1000000
        and new.sold_at is distinct from old.sold_at
        and new.uid is not distinct from old.uid then
    -- Une ancienne version vient d'écraser cette ligne avec une AUTRE
    -- vente portant le même numéro. L'uid suit le contenu : la vente
    -- écrasée redevient « absente du serveur », et son poste pourra la
    -- renvoyer, au lieu de croire qu'elle y est toujours.
    new.uid := md5(new.id::text || '|'
                   || floor(extract(epoch from new.sold_at))::bigint::text)::uuid;
  end if;
  if new.numero_local is null then
    new.numero_local := new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists mirror_sales_identite on public.mirror_sales;
create trigger mirror_sales_identite
  before insert or update on public.mirror_sales
  for each row execute function public.bs_mirror_sales_identite();

create or replace function public.bs_mirror_sale_lines_identite()
returns trigger
language plpgsql
as $$
begin
  if new.uid is null then
    select md5(s.uid::text || '|' || new.id::text)::uuid
      into new.uid
      from public.mirror_sales s
     where s.id = new.sale_id;
    new.uid := coalesce(new.uid, gen_random_uuid());
  end if;
  return new;
end;
$$;

drop trigger if exists mirror_sale_lines_identite on public.mirror_sale_lines;
create trigger mirror_sale_lines_identite
  before insert on public.mirror_sale_lines
  for each row execute function public.bs_mirror_sale_lines_identite();

-- Les colonnes sont remplies partout : on interdit le vide.
alter table public.mirror_sales      alter column uid set not null;
alter table public.mirror_sale_lines alter column uid set not null;

commit;

-- ── Vérification (à lancer après) ─────────────────────────────────────
-- select count(*) as ventes, count(distinct uid) as identites
--   from public.mirror_sales;
-- Les deux nombres doivent être égaux.
