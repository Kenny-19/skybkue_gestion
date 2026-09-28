-- ═══════════════════════════════════════════════════════════════════════
-- L'HÔTEL TARIFIE EN DOLLARS — colonnes miroir
-- ═══════════════════════════════════════════════════════════════════════
--
-- À exécuter dans Supabase → SQL Editor. Rejouable sans risque.
--
-- Le modèle
-- ---------
-- Le dollar devient la SAISIE : c'est le prix annoncé au client, et donc
-- la seule valeur qu'on tape. Le franc reste la monnaie d'ENCAISSEMENT
-- — la caisse, les dettes et les rapports sont en FC — mais il se
-- calcule au taux. Un tarif de chambre ne doit pas bouger parce que le
-- franc a bougé.
--
-- Pourquoi le taux se fige sur le séjour
-- --------------------------------------
-- Le taux applicatif est une valeur unique et COURANTE. Une facture
-- émise à 2300 FC/USD puis réimprimée alors que le taux est passé à 2600
-- annoncerait un total en dollars que le client n'a jamais payé. Chaque
-- séjour porte donc le taux de son check-out — `fc_per_usd_cents`,
-- stocké × 100 pour rester un entier : un taux est une donnée
-- comptable, il ne s'arrondit pas au hasard des divisions.
--
-- 0 signifie « séjour antérieur à la bascule » : on retombe alors sur le
-- taux courant, faute de mieux, et l'écran le dit.
--
-- Les remises
-- -----------
-- Une remise en POURCENTAGE est neutre en devise : 10 % restent 10 %,
-- rien n'est converti, et c'est ce qui la rend fiable sur la facture.
-- Une remise en MONTANT, elle, passe en dollars — « je lui fais 10 de
-- moins » veut dire dix dollars, et doit encore valoir dix dollars l'an
-- prochain. Le poste convertit sa base locale tout seul (migration v25).

alter table public.mirror_rooms
  add column if not exists price_usd_cents bigint not null default 0;

alter table public.mirror_stay_rooms
  add column if not exists price_usd_cents bigint not null default 0,
  add column if not exists list_usd_cents  bigint;

alter table public.mirror_stays
  add column if not exists fc_per_usd_cents bigint not null default 0;

notify pgrst, 'reload schema';

-- ── Contrôle ───────────────────────────────────────────────────────────
-- Après la prochaine synchronisation, chaque chambre doit porter un
-- tarif dans les deux devises, cohérent au taux :
--
--   select number, type,
--          price_usd_cents / 100.0                       as tarif_usd,
--          price_per_night_cents                         as tarif_fc,
--          round(price_per_night_cents
--                / nullif(price_usd_cents / 100.0, 0))   as taux_implicite
--   from   public.mirror_rooms
--   order  by number;
--
-- Et chaque séjour récent doit porter son taux figé :
--
--   select receipt_number, checkout_at, fc_per_usd_cents / 100.0 as taux
--   from   public.mirror_stays
--   order  by checkout_at desc
--   limit  10;
