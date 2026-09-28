-- ═══════════════════════════════════════════════════════════════════════
-- STOCK EN DELTAS — le serveur calcule, les postes déclarent
-- ═══════════════════════════════════════════════════════════════════════
--
-- À exécuter dans Supabase → SQL Editor. Rejouable sans risque.
--
-- Le problème que ça résout
-- -------------------------
-- Jusqu'ici chaque poste envoyait une quantité ABSOLUE : « stock = 7 ».
-- Deux postes qui vendent pendant la même coupure écrasent alors le
-- travail l'un de l'autre.
--
--   Il reste 10 Primus. Le bar en vend 3 → il enverra « 7 ».
--   La terrasse en vend 4 → elle enverra « 6 ».
--   Le dernier arrivé gagne : la base annonce 6, il en reste 3.
--   Les ventes du premier poste ont disparu du stock.
--
-- Avec un delta, chaque poste déclare son INTENTION — « −3 », « −4 » —
-- et Postgres applique les deux : 10 − 3 − 4 = 3. L'ordre d'arrivée n'a
-- plus d'importance, ce qui rend le hors-ligne viable.
--
-- Le stock négatif est ACCEPTÉ
-- ----------------------------
-- Si le total dépasse ce qui était en stock, on descend en négatif et on
-- l'enregistre. Ces ventes ont déjà eu lieu : les bouteilles sont
-- sorties du frigo, le client a payé et il est parti. Une base de
-- données n'a pas le pouvoir d'annuler ça. Le négatif n'est pas un bug,
-- c'est un écart à justifier — stock initial faux, casse, ou vol.
-- Refuser l'opération perdrait la vente ET l'information.

create extension if not exists pgcrypto with schema extensions;

-- ── 1. Journal des mouvements ──────────────────────────────────────────
-- Chaque ligne est un mouvement déclaré par un poste. `op_id` est généré
-- par le poste AVANT l'envoi : c'est lui qui rend l'opération rejouable
-- sans effet. La coupure ne se produit jamais proprement — le serveur
-- peut enregistrer puis perdre le réseau avant l'accusé de réception,
-- et le poste renverra. Sans cette clé, il facturerait deux fois.
create table if not exists public.app_stock_moves (
  op_id       text primary key,
  article_id  bigint not null,
  delta       int not null,
  reason      text,
  poste       text,
  occurred_at timestamptz not null default now(),
  applied_at  timestamptz not null default now()
);

create index if not exists app_stock_moves_article_idx
  on public.app_stock_moves (article_id, occurred_at desc);

alter table public.app_stock_moves enable row level security;
revoke all on public.app_stock_moves from anon, authenticated;

-- ── 2. Appliquer un mouvement ──────────────────────────────────────────
-- La quantité vit dans `mirror_articles.stock_qty`, et à partir de
-- maintenant SEULE cette fonction y touche. Les postes ne poussent plus
-- de quantité absolue — sinon ils écraseraient le calcul du serveur.
create or replace function public.bs_adjust_stock(
  p_op_id      text,
  p_article_id bigint,
  p_delta      int,
  p_reason     text default null,
  p_poste      text default null
) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare
  nouvelle int;
begin
  if p_op_id is null or length(trim(p_op_id)) = 0 then
    raise exception 'OP_ID_MANQUANT';
  end if;

  -- Déjà appliqué : on renvoie l'état courant sans rien refaire.
  if exists (select 1 from public.app_stock_moves where op_id = p_op_id) then
    select stock_qty into nouvelle
      from public.mirror_articles where id = p_article_id;
    return json_build_object(
      'status', 'deja_applique', 'stock_qty', coalesce(nouvelle, 0));
  end if;

  if not exists (select 1 from public.mirror_articles
                  where id = p_article_id) then
    raise exception 'ARTICLE_INCONNU';
  end if;

  insert into public.app_stock_moves
    (op_id, article_id, delta, reason, poste)
  values (trim(p_op_id), p_article_id, p_delta, p_reason, p_poste);

  -- Le négatif n'est pas borné : cf. l'explication en tête de fichier.
  update public.mirror_articles
     set stock_qty = coalesce(stock_qty, 0) + p_delta
   where id = p_article_id
  returning stock_qty into nouvelle;

  return json_build_object('status', 'applique', 'stock_qty', nouvelle);
end;
$$;

-- ── 3. Droits ──────────────────────────────────────────────────────────
-- PUBLIC d'abord : sans ça le revoke ne retire rien (cf. la faille de
-- septembre sur bs_check_credentials).
revoke execute on function public.bs_adjust_stock(
  text, bigint, int, text, text) from public;
grant execute on function public.bs_adjust_stock(
  text, bigint, int, text, text) to anon, authenticated;

notify pgrst, 'reload schema';

-- ── 4. Contrôle ────────────────────────────────────────────────────────
-- Rejouer deux fois le même op_id ne doit bouger le stock qu'une fois :
--
--   select public.bs_adjust_stock('test-1', <id>, -3, 'essai');
--   select public.bs_adjust_stock('test-1', <id>, -3, 'essai');
--   -- le second renvoie {"status":"deja_applique", ...}
--
--   delete from public.app_stock_moves where op_id = 'test-1';
--   update public.mirror_articles set stock_qty = stock_qty + 3
--    where id = <id>;   -- remise en état après l'essai
