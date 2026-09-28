-- ═══════════════════════════════════════════════════════════════════════
-- MIROIR DES SÉJOURS — pour que Pamela voie le chiffre d'affaires hôtel
-- ═══════════════════════════════════════════════════════════════════════
--
-- À exécuter dans Supabase → SQL Editor. Rejouable sans risque.
--
-- Pourquoi ce fichier
-- -------------------
-- Le tableau de bord de Pamela lit les tables `mirror_*`. Les ventes du
-- bar et du restaurant y sont depuis le début ; les SÉJOURS, non. Elle
-- ne voyait donc que l'état des chambres — jamais une nuitée facturée,
-- jamais un franc d'hébergement.
--
-- Le code de poussée existait déjà côté application (`_stayJson`,
-- `_stayRoomJson` dans mirror_service.dart) mais n'était appelé nulle
-- part, faute de tables où écrire. Les colonnes ci-dessous reprennent
-- exactement sa sortie.
--
-- Ce miroir est en LECTURE pour le tableau de bord : la source de vérité
-- reste la base du poste. On ne restaure jamais un séjour depuis ici.

create table if not exists public.mirror_stays (
  id                        bigint primary key,
  receipt_number            text not null,
  reservation_number        text,
  generated_at              timestamptz,
  checkin_at                timestamptz not null,
  checkout_at               timestamptz not null,

  -- Occupant
  guest_full_name           text not null,
  guest_nationality         text,
  guest_phone               text,
  guest_email               text,

  -- Payeur au moment de la facture (figé : une société peut changer de
  -- nom, la facture émise ne change pas).
  payer_name                text,
  payer_tax_id              text,
  payer_address             text,
  payer_contact             text,

  -- Facturation, en cents de franc congolais.
  subtotal_cents            bigint not null default 0,
  remise_cents              bigint not null default 0,
  remise_kind               smallint not null default 0,  -- 0=montant, 1=%
  remise_value              bigint not null default 0,
  remise_base               smallint not null default 1,  -- 0=hébergement, 1=total
  remise_reason             text,
  acompte_fc_cents          bigint not null default 0,
  acompte_usd_cents         bigint not null default 0,
  payment_mode              smallint not null default 0,

  -- Métadonnées
  stay_group                text,
  server_login              text,
  note                      text,
  extras_json               text not null default '[]',
  client_visits_at_checkout int not null default 0,

  synced_at                 timestamptz not null default now()
);

-- Chambres facturées dans un séjour. Un séjour groupé (une société qui
-- loue quatre chambres) produit quatre lignes pour une seule facture.
create table if not exists public.mirror_stay_rooms (
  id                     bigint primary key,
  stay_id                bigint not null
                           references public.mirror_stays(id) on delete cascade,
  room_number            text not null,
  room_type              text not null,
  checkin_at             timestamptz not null,
  checkout_at            timestamptz not null,
  price_per_night_cents  bigint not null,
  -- Tarif catalogue au moment du check-out. Null ou égal au prix
  -- facturé → aucun tarif négocié sur cette chambre.
  list_price_cents       bigint,
  nights                 int not null default 1,
  synced_at              timestamptz not null default now()
);

-- Le tableau de bord filtre toujours par date de départ.
create index if not exists mirror_stays_checkout_idx
  on public.mirror_stays (checkout_at desc);
create index if not exists mirror_stay_rooms_stay_idx
  on public.mirror_stay_rooms (stay_id);

-- ── Droits ─────────────────────────────────────────────────────────────
-- Même régime que les autres tables miroir : l'application écrit avec la
-- clé anon, le tableau de bord lit.
alter table public.mirror_stays      enable row level security;
alter table public.mirror_stay_rooms enable row level security;

drop policy if exists mirror_stays_all on public.mirror_stays;
create policy mirror_stays_all on public.mirror_stays
  for all to anon, authenticated using (true) with check (true);

drop policy if exists mirror_stay_rooms_all on public.mirror_stay_rooms;
create policy mirror_stay_rooms_all on public.mirror_stay_rooms
  for all to anon, authenticated using (true) with check (true);

notify pgrst, 'reload schema';

-- ── Contrôle ───────────────────────────────────────────────────────────
-- Après un check-out dans l'application, cette requête doit renvoyer la
-- facture correspondante :
--
--   select receipt_number, guest_full_name, checkout_at,
--          subtotal_cents - remise_cents as net_cents
--   from   public.mirror_stays
--   order  by checkout_at desc
--   limit  5;
