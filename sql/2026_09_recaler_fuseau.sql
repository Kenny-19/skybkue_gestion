-- ═══════════════════════════════════════════════════════════════════════
-- RECALAGE DU FUSEAU — rattraper les lignes du miroir restées à +2h
-- ═══════════════════════════════════════════════════════════════════════
--
-- ⚠ LIS CECI AVANT DE L'EXÉCUTER. Ce script n'est probablement PAS
--   nécessaire, et l'exécuter au mauvais moment fausserait les montants
--   une seconde fois, dans l'autre sens.
--
-- Le défaut
-- ---------
-- L'application envoyait ses dates avec `toIso8601String()` appliqué à
-- une date LOCALE : « 2026-09-21T06:45:52.000 », sans décalage. Postgres
-- lit ce texte dans un `timestamptz` en supposant son propre fuseau,
-- UTC. Une vente de 6h45 à Lubumbashi (UTC+2, donc 4h45 UTC) était donc
-- classée à 6h45 UTC — deux heures dans le futur.
--
-- Mesuré le 21 septembre 2026 : 194 des 205 ventes du miroir étaient à
-- exactement +2h de leur `synced_at`, que le serveur pose lui-même avec
-- now(). Les 11 autres sont des envois de rattrapage, décalés pareil.
--
-- Conséquence : toute vente après 22h à Lubumbashi basculait sur le
-- lendemain. Le chiffre du jour de Pamela perdait la fin de soirée, et
-- le lendemain était crédité de ventes qui n'étaient pas les siennes.
--
-- Pourquoi ce script est probablement inutile
-- -------------------------------------------
-- `MirrorService.syncAll()` fait un upsert de TOUTES les ventes encore
-- présentes dans la base du poste, toutes les dix minutes. Dès qu'un
-- poste tourne sur la version corrigée, il réécrit donc lui-même ses
-- lignes avec les bonnes dates. C'est le chemin à privilégier : il ne
-- suppose rien, il republie la vérité depuis la source.
--
-- Ce script ne sert qu'aux ORPHELINES : les lignes du miroir dont la
-- vente n'existe plus dans aucune base locale (poste réinstallé, base
-- purgée). Elles resteront à +2h indéfiniment, puisque plus personne ne
-- les republie.
--
-- Marche à suivre
-- ---------------
--  1. Déployer la version corrigée sur TOUS les postes.
--  2. Les laisser tourner et se synchroniser (dix minutes suffisent).
--  3. Lancer la section 1 ci-dessous : elle ne fait que MESURER.
--  4. S'il reste des lignes à +2h, et seulement alors, lancer la
--     section 2 en remplaçant la date de coupure.

-- ── 1. Mesure (ne modifie rien) ────────────────────────────────────────
-- Combien de lignes n'ont pas été republiées depuis le déploiement ?
-- Remplace la date par celle de ton déploiement.
select
  count(*)                                              as total,
  count(*) filter (where synced_at < '2026-09-21T11:54:00Z') as jamais_republiees,
  count(*) filter (where synced_at >= '2026-09-21T11:54:00Z') as deja_corrigees
from public.mirror_sales;

-- Et l'écart résiduel, vente par vente. Après correction il doit être
-- proche de zéro sur les lignes republiées.
select id, sold_at, synced_at,
       round(extract(epoch from (sold_at - synced_at)) / 3600, 2) as ecart_h
from   public.mirror_sales
order  by synced_at desc
limit  20;

-- ── 2. Rattrapage des orphelines ───────────────────────────────────────
-- N'exécute ce bloc QUE si la section 1 montre des lignes non
-- republiées. La date de coupure est la barrière : une ligne déjà
-- réécrite par l'application corrigée ne doit surtout pas être touchée.
--
-- Décommente, ajuste la date, exécute.
--
-- do $$
-- declare
--   coupure constant timestamptz := '2026-09-21T11:54:00Z';
--   n int;
-- begin
--   if exists (select 1 from public.app_migrations
--               where nom = 'recalage_fuseau_2026_09') then
--     raise notice 'Déjà appliqué — rien à faire.';
--     return;
--   end if;
--
--   update public.mirror_sales
--      set sold_at    = sold_at    - interval '2 hours',
--          settled_at = settled_at - interval '2 hours'
--    where synced_at < coupure;
--   get diagnostics n = row_count;
--
--   if to_regclass('public.mirror_stays') is not null then
--     update public.mirror_stays
--        set generated_at = generated_at - interval '2 hours',
--            checkin_at   = checkin_at   - interval '2 hours',
--            checkout_at  = checkout_at  - interval '2 hours'
--      where synced_at < coupure;
--   end if;
--
--   insert into public.app_migrations (nom, note)
--   values ('recalage_fuseau_2026_09',
--           format('-2h sur %s ventes orphelines', n));
--   raise notice 'Recalé : % ventes orphelines.', n;
-- end $$;

-- Le verrou, créé d'avance pour que la section 2 puisse s'y référer.
create table if not exists public.app_migrations (
  nom        text primary key,
  applied_at timestamptz not null default now(),
  note       text
);

-- `synced_at` n'est jamais touché : c'est le serveur qui le pose, avec
-- now(). Il était juste depuis le début, et c'est précisément ce qui
-- permet de mesurer le décalage et de distinguer les lignes republiées.
