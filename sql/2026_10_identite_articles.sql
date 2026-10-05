-- =====================================================================
-- IDENTITÉ DES ARTICLES + FUSION DES DOUBLONS
-- =====================================================================
--
-- Constat (6 octobre 2026) : 114 articles sur le serveur, dont 16 noms en
-- double sur 42 lignes. Cause : `mirror_articles.id` était le numéro
-- LOCAL du poste qui avait créé l'article. Chaque poste neuf renvoyait
-- son catalogue sous ses propres numéros, et les mouvements de stock
-- (`bs_adjust_stock(p_article_id)`) visaient ce numéro local — donc, sur
-- un autre poste, potentiellement un AUTRE produit.
--
-- La correction :
--   * chaque article porte un `uid` DÉDUIT DE SON NOM :
--       md5('A|' || btrim(name))::uuid
--     Les postes reconnaissaient déjà un produit à son nom ; tous
--     calculent désormais le même identifiant pour le même produit
--     (lib/core/identite.dart, uidArticle) ;
--   * les doublons sont FUSIONNÉS : une ligne gardée par nom (active
--     d'abord, puis la plus mouvementée, puis la plus vendue, puis la plus
--     ancienne) ; les autres sont archivées dans `app_fusion_articles`
--     avec leur stock, puis supprimées ;
--   * les lignes de vente et les mouvements de stock pointent sur l'article
--     gardé ;
--   * nouvelle fonction `bs_adjust_stock_uid`, qui vise l'article par son
--     uid. L'ancienne reste pour les postes pas encore à jour, et retrouve
--     un article fusionné par son ancien numéro.
--
-- Le stock gardé est celui de la ligne conservée : les copies portaient
-- surtout les anciennes valeurs d'exemple. Leurs stocks restent lisibles
-- dans `app_fusion_articles` — un inventaire physique tranche.
--
-- À EXÉCUTER UNE FOIS dans Supabase → SQL Editor, AVANT de publier la
-- version qui envoie les articles par uid. Rejouable.
-- =====================================================================

begin;

-- ── 1. Colonnes ───────────────────────────────────────────────────────
alter table public.mirror_articles add column if not exists uid uuid;
alter table public.app_stock_moves add column if not exists article_uid uuid;

-- ⚠️ Même formule que uidArticle() dans l'application.
update public.mirror_articles
   set uid = md5('A|' || btrim(name))::uuid
 where uid is null;

-- ── 2. Journal de fusion ──────────────────────────────────────────────
create table if not exists public.app_fusion_articles (
  ancien_id     bigint primary key,
  garde_id      bigint not null,
  uid           uuid   not null,
  name          text   not null,
  active        boolean,
  stock_qty     int,
  price_cents   bigint,
  fusionne_le   timestamptz not null default now()
);
alter table public.app_fusion_articles enable row level security;
revoke all on public.app_fusion_articles from anon, authenticated;

-- ── 3. Choix de la ligne gardée, par uid ──────────────────────────────
create temporary table _choix on commit drop as
with stats as (
  select a.id, a.uid, a.active,
         (select count(*) from public.app_stock_moves m
           where m.article_id = a.id)                       as mouvements,
         (select count(*) from public.mirror_sale_lines l
           where l.article_id = a.id)                       as ventes
    from public.mirror_articles a
)
select id, uid,
       first_value(id) over (
         partition by uid
         order by active desc nulls last, mouvements desc, ventes desc, id asc
       ) as garde_id
  from stats;

insert into public.app_fusion_articles
  (ancien_id, garde_id, uid, name, active, stock_qty, price_cents)
select a.id, c.garde_id, a.uid, a.name, a.active, a.stock_qty, a.price_cents
  from public.mirror_articles a
  join _choix c on c.id = a.id
 where c.id <> c.garde_id
on conflict (ancien_id) do nothing;

-- ── 4. Tout repointer vers la ligne gardée ────────────────────────────
-- Les lignes de vente, par NOM, TOUTES : leur article_id venait du numéro
-- local du poste et pouvait désigner un autre produit sur le serveur
-- (une ligne « Fanta » pointant sur le Coca). Une ligne dont le produit a
-- été renommé depuis garde son ancien nom, ne correspond à rien, et
-- reste telle quelle.
update public.mirror_sale_lines l
   set article_id = g.id
  from public.mirror_articles g
  join _choix c on c.id = g.id and c.id = c.garde_id
 where btrim(l.article_name) = btrim(g.name)
   and l.article_id is distinct from g.id;

update public.app_stock_moves m
   set article_id = c.garde_id
  from _choix c
 where m.article_id = c.id
   and c.id <> c.garde_id;

update public.app_stock_moves m
   set article_uid = a.uid
  from public.mirror_articles a
 where a.id = m.article_id
   and m.article_uid is null;

delete from public.mirror_articles a
 using _choix c
 where c.id = a.id
   and c.id <> c.garde_id;

-- ── 5. Unicité, numérotation serveur ──────────────────────────────────
create unique index if not exists mirror_articles_uid_key
  on public.mirror_articles (uid);

create sequence if not exists public.mirror_articles_id_seq start with 1000000;
alter sequence public.mirror_articles_id_seq owned by public.mirror_articles.id;
alter table public.mirror_articles
  alter column id set default nextval('public.mirror_articles_id_seq');
grant usage, select on sequence public.mirror_articles_id_seq to anon, authenticated;

-- Postes pas encore à jour : ils envoient sans uid. On le calcule ; s'il
-- existe déjà (même produit sous un autre numéro), l'insertion échoue au
-- lieu de recréer un doublon.
create or replace function public.bs_mirror_articles_identite()
returns trigger
language plpgsql
as $$
begin
  if new.uid is null then
    new.uid := md5('A|' || btrim(new.name))::uuid;
  end if;
  return new;
end;
$$;

drop trigger if exists mirror_articles_identite on public.mirror_articles;
create trigger mirror_articles_identite
  before insert on public.mirror_articles
  for each row execute function public.bs_mirror_articles_identite();

alter table public.mirror_articles alter column uid set not null;

-- ── 6. Mouvements de stock par uid ────────────────────────────────────
create or replace function public.bs_adjust_stock_uid(
  p_op_id       text,
  p_article_uid uuid,
  p_delta       int,
  p_reason      text default null,
  p_poste       text default null
) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_id     bigint;
  nouvelle int;
begin
  if p_op_id is null or length(trim(p_op_id)) = 0 then
    raise exception 'OP_ID_MANQUANT';
  end if;

  select id into v_id from public.mirror_articles where uid = p_article_uid;

  if exists (select 1 from public.app_stock_moves where op_id = p_op_id) then
    select stock_qty into nouvelle from public.mirror_articles where id = v_id;
    return json_build_object(
      'status', 'deja_applique', 'stock_qty', coalesce(nouvelle, 0));
  end if;

  if v_id is null then
    raise exception 'ARTICLE_INCONNU';
  end if;

  insert into public.app_stock_moves
    (op_id, article_id, article_uid, delta, reason, poste)
  values (trim(p_op_id), v_id, p_article_uid, p_delta, p_reason, p_poste);

  update public.mirror_articles
     set stock_qty = coalesce(stock_qty, 0) + p_delta
   where id = v_id
  returning stock_qty into nouvelle;

  return json_build_object('status', 'applique', 'stock_qty', nouvelle);
end;
$$;

revoke execute on function public.bs_adjust_stock_uid(
  text, uuid, int, text, text) from public;
grant execute on function public.bs_adjust_stock_uid(
  text, uuid, int, text, text) to anon, authenticated;

-- L'ancienne fonction, pour les postes pas encore à jour : un numéro
-- d'article fusionné est redirigé vers l'article gardé.
create or replace function public.bs_adjust_stock(
  p_op_id      text,
  p_article_id bigint,
  p_delta      int,
  p_reason     text default null,
  p_poste      text default null
) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_id bigint := p_article_id;
  v_uid uuid;
  nouvelle int;
begin
  if p_op_id is null or length(trim(p_op_id)) = 0 then
    raise exception 'OP_ID_MANQUANT';
  end if;

  if not exists (select 1 from public.mirror_articles where id = v_id) then
    select garde_id into v_id
      from public.app_fusion_articles where ancien_id = p_article_id;
  end if;

  if exists (select 1 from public.app_stock_moves where op_id = p_op_id) then
    select stock_qty into nouvelle from public.mirror_articles where id = v_id;
    return json_build_object(
      'status', 'deja_applique', 'stock_qty', coalesce(nouvelle, 0));
  end if;

  select uid into v_uid from public.mirror_articles where id = v_id;
  if v_uid is null then
    raise exception 'ARTICLE_INCONNU';
  end if;

  insert into public.app_stock_moves
    (op_id, article_id, article_uid, delta, reason, poste)
  values (trim(p_op_id), v_id, v_uid, p_delta, p_reason, p_poste);

  update public.mirror_articles
     set stock_qty = coalesce(stock_qty, 0) + p_delta
   where id = v_id
  returning stock_qty into nouvelle;

  return json_build_object('status', 'applique', 'stock_qty', nouvelle);
end;
$$;

revoke execute on function public.bs_adjust_stock(
  text, bigint, int, text, text) from public;
grant execute on function public.bs_adjust_stock(
  text, bigint, int, text, text) to anon, authenticated;

notify pgrst, 'reload schema';

commit;

-- ── Vérification ──────────────────────────────────────────────────────
-- select count(*) as articles, count(distinct uid) as identites
--   from public.mirror_articles;              -- égaux, 88 attendus
-- select name, ancien_id, garde_id, stock_qty
--   from public.app_fusion_articles order by name;  -- 26 lignes fusionnées
