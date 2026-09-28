-- ═══════════════════════════════════════════════════════════════════════
-- ENCOURS DES CRÉDITS — ce qui reste dû, visible sur le site
-- ═══════════════════════════════════════════════════════════════════════
--
-- À exécuter dans Supabase → SQL Editor. Rejouable sans risque.
--
-- Pourquoi une colonne de plus
-- ----------------------------
-- Jusqu'ici une dette se soldait d'un bloc : `settled_at` null voulait
-- dire « le ticket entier reste dû ». Depuis les règlements partiels,
-- c'est faux. Un client qui a versé 40 000 sur 50 000 doit encore
-- 10 000 — mais le tableau de bord, qui ne connaît que `settled_at`,
-- afficherait 50 000.
--
-- L'erreur va toujours dans le même sens : elle GROSSIT l'encours. Ce
-- qui est la pire direction pour un chiffre qui sert à décider s'il faut
-- relancer un client.
--
-- `paid_cents` porte ce que le poste a déjà encaissé sur la vente. Le
-- reste dû se calcule : total des lignes − paid_cents.

alter table public.mirror_sales
  add column if not exists paid_cents bigint not null default 0;

-- Le tableau de bord filtre les dettes en cours par date.
create index if not exists mirror_sales_credit_idx
  on public.mirror_sales (on_credit, settled_at, sold_at desc);

notify pgrst, 'reload schema';

-- ── Contrôle ───────────────────────────────────────────────────────────
-- L'encours réel, après la prochaine synchronisation :
--
--   select s.id, s.customer_name, s.sold_at,
--          coalesce(sum(l.qty * l.unit_price_cents), 0) as total_cents,
--          s.paid_cents,
--          coalesce(sum(l.qty * l.unit_price_cents), 0) - s.paid_cents
--            as reste_cents
--   from   public.mirror_sales s
--   left   join public.mirror_sale_lines l on l.sale_id = s.id
--   where  s.on_credit and s.settled_at is null
--   group  by s.id, s.customer_name, s.sold_at, s.paid_cents
--   having coalesce(sum(l.qty * l.unit_price_cents), 0) > s.paid_cents
--   order  by s.sold_at;
