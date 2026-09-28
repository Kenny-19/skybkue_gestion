-- =========================================================================
-- SKYBLUE — Setup Supabase complet (app Flutter + dashboard web + push)
--
-- À exécuter dans : Supabase → SQL Editor → New query → coller → Run.
-- Le script est IDEMPOTENT : tu peux le rejouer sans casser l'existant.
-- =========================================================================

-- 0. Extensions -----------------------------------------------------------
create extension if not exists pg_net with schema extensions; -- webhooks


-- =========================================================================
-- 1. MIROIR (l'app Flutter pousse ses données ici, dashboard + autres postes
--    les lisent). Écritures faites par le client anon → RLS désactivée.
-- =========================================================================

-- 1.1 Articles ------------------------------------------------------------
create table if not exists public.mirror_articles (
  id                 bigint      primary key,
  name               text        not null,
  price_cents        bigint      not null,
  category           smallint    not null,
  active             boolean     not null default true,
  track_stock        boolean     not null default false,
  unit               text        not null default 'unité',
  stock_qty          integer     not null default 0,
  threshold          integer     not null default 0,
  image_path         text
);

-- 1.2 Chambres (PK naturelle = number) ------------------------------------
create table if not exists public.mirror_rooms (
  number                 text        primary key,
  type                   text        not null,
  price_per_night_cents  bigint      not null,
  status                 smallint    not null default 0,
  current_guest          text,
  checkout_date          timestamptz,
  checkin_note           text,
  checkin_at             timestamptz
);
-- Colonnes ajoutées après coup (idempotent, ne casse jamais l'existant) :
alter table public.mirror_rooms add column if not exists checkin_note text;
alter table public.mirror_rooms add column if not exists checkin_at   timestamptz;
alter table public.mirror_rooms add column if not exists stay_group   text;
alter table public.mirror_rooms add column if not exists payer_id     bigint;
alter table public.mirror_rooms add column if not exists image_path   text;
create index if not exists idx_mirror_rooms_stay_group
  on public.mirror_rooms(stay_group);
create index if not exists idx_mirror_rooms_payer
  on public.mirror_rooms(payer_id);

-- 1.3 Comptes utilisateurs (sans password — jamais miroité) ---------------
create table if not exists public.mirror_users (
  id          bigint      primary key,
  full_name   text        not null,
  login       text        not null unique,
  role        smallint    not null,
  active      boolean     not null default true,
  created_at  timestamptz not null default now(),
  last_login  timestamptz
);

-- 1.4 Ventes --------------------------------------------------------------
create table if not exists public.mirror_sales (
  id              bigint      primary key,
  sold_at         timestamptz not null,
  server_user_id  bigint,
  payment         smallint    not null,
  location        smallint    not null default 0,
  customer_name   text,
  room_number     text,
  on_credit       boolean     not null default false,
  settled_at      timestamptz,
  note            text
);

-- 1.5 Lignes de vente -----------------------------------------------------
create table if not exists public.mirror_sale_lines (
  id                bigint      primary key,
  sale_id           bigint      not null references public.mirror_sales(id) on delete cascade,
  article_id        bigint,
  article_name      text        not null,
  qty               integer     not null,
  unit_price_cents  bigint      not null
);
create index if not exists idx_mirror_sale_lines_sale on public.mirror_sale_lines(sale_id);


-- =========================================================================
-- 2. DEMANDES DE RAVITAILLEMENT (cloud-first : écrit direct, pas de miroir).
--    Consulté par le dashboard (Pamela approuve/rejette) + hub de notifs.
-- =========================================================================
create table if not exists public.supply_requests (
  id                    bigserial   primary key,
  article_id            bigint,
  article_name          text        not null,
  location              smallint    not null default 0,
  qty_requested         integer     not null,
  qty_at_request        integer     not null default 0,
  threshold_at_request  integer     not null default 0,
  requested_by_login    text        not null,
  requested_at          timestamptz not null default now(),
  status                text        not null default 'pending'
    check (status in ('pending','approved','rejected','fulfilled')),
  reviewed_by_login     text,
  reviewed_at           timestamptz,
  review_note           text
);
create index if not exists idx_supply_requests_status on public.supply_requests(status);
create index if not exists idx_supply_requests_login  on public.supply_requests(requested_by_login);
create index if not exists idx_supply_requests_date   on public.supply_requests(requested_at desc);


-- =========================================================================
-- 2.b FIDÉLITÉ CLIENT + PAYEURS TIERS (prise en charge société / privée).
-- =========================================================================
create table if not exists public.mirror_clients (
  id                 bigint      primary key,
  full_name          text        not null,
  phone              text        unique,
  email              text,
  notes              text,
  first_seen_at      timestamptz not null default now(),
  last_seen_at       timestamptz not null default now(),
  visits_count       integer     not null default 0,
  total_spent_cents  bigint      not null default 0
);
create index if not exists idx_mirror_clients_lastseen
  on public.mirror_clients(last_seen_at desc);

create table if not exists public.mirror_payers (
  id          bigint      primary key,
  name        text        not null,
  type        smallint    not null default 1,
  tax_id      text,
  address     text,
  contact     text,
  notes       text,
  created_at  timestamptz not null default now()
);
create index if not exists idx_mirror_payers_name
  on public.mirror_payers(lower(name));


-- =========================================================================
-- 2.c RAPPORTS ENVOYÉS À PAMELA (PDF stockés bucket + trace).
-- =========================================================================
create table if not exists public.sent_reports (
  id                  bigserial   primary key,
  name                text        not null,
  period              text,
  kind                text        not null default 'summary',
  storage_path        text        not null,
  public_url          text,
  size_bytes          integer     not null default 0,
  generated_by_login  text,
  note                text,
  generated_at        timestamptz not null default now(),
  read_at             timestamptz -- set par le dashboard quand ouvert
);
create index if not exists idx_sent_reports_date
  on public.sent_reports(generated_at desc);


-- =========================================================================
-- 3. RÉSERVATIONS FUTURES (miroir des tables locales Flutter).
-- =========================================================================
create table if not exists public.mirror_reservations (
  id                  bigint      primary key,
  reservation_number  text        not null unique,
  created_at          timestamptz not null default now(),
  checkin_date        timestamptz not null,
  checkout_date       timestamptz not null,
  guest_full_name     text        not null,
  guest_phone         text,
  guest_email         text,
  payer_id            bigint,
  status              smallint    not null default 1,
  deposit_cents       bigint      not null default 0,
  note                text,
  created_by_login    text,
  cancelled_at        timestamptz,
  cancel_reason       text,
  stay_id             bigint
);
create index if not exists idx_mirror_reservations_checkin
  on public.mirror_reservations(checkin_date);

create table if not exists public.mirror_reservation_rooms (
  id                    bigint  primary key,
  reservation_id        bigint  not null,
  room_number           text    not null,
  price_per_night_cents bigint  not null
);
create index if not exists idx_mirror_reservation_rooms_res
  on public.mirror_reservation_rooms(reservation_id);


-- =========================================================================
-- 3. LOGS D'ERREURS (app Flutter → email via webhook Edge Function).
-- =========================================================================
create table if not exists public.error_logs (
  id           bigserial   primary key,
  message      text        not null,
  stack        text,
  context      text,
  app_version  text,
  platform     text,
  occurred_at  timestamptz not null default now()
);
create index if not exists idx_error_logs_date on public.error_logs(occurred_at desc);


-- =========================================================================
-- 4. PUSH NOTIFICATIONS (PWA du dashboard).
-- =========================================================================
create table if not exists public.push_subscriptions (
  endpoint    text        primary key,
  p256dh      text        not null,
  auth        text        not null,
  user_login  text,
  user_agent  text,
  created_at  timestamptz not null default now(),
  last_sent   timestamptz
);

create table if not exists public.push_alert_state (
  article_id       integer     primary key,
  last_notified_at timestamptz not null default now(),
  last_qty         integer     not null default 0
);


-- =========================================================================
-- 5. COMPTE PROPRIÉTAIRE DU DASHBOARD WEB (auth bcrypt, séparé du miroir).
-- =========================================================================
create table if not exists public.dashboard_owners (
  id            bigserial   primary key,
  login         text        not null unique,
  full_name     text        not null,
  password_hash text        not null,
  active        boolean     not null default true,
  created_at    timestamptz not null default now(),
  last_login    timestamptz
);

-- Compte Pamela (mot de passe = 002026). Rejouable sans écraser.
insert into public.dashboard_owners (login, full_name, password_hash)
values ('pamela', 'Pamela',
        '$2b$10$QZYYShGQTvsi/nrFW7xqLueZy6oaPS7C4BGzTrO1oWdrLfi73w.NS')
on conflict (login) do nothing;


-- =========================================================================
-- 6. RLS — désactivée sur toutes les tables ci-dessus.
--    Justification : projet Supabase mono-tenant, clé anon = clé applicative,
--    aucun accès public à l'API en dehors des apps qu'on contrôle.
-- =========================================================================
alter table public.mirror_articles           disable row level security;
alter table public.mirror_rooms              disable row level security;
alter table public.mirror_users              disable row level security;
alter table public.mirror_sales              disable row level security;
alter table public.mirror_sale_lines         disable row level security;
alter table public.mirror_clients            disable row level security;
alter table public.mirror_payers             disable row level security;
alter table public.mirror_reservations       disable row level security;
alter table public.mirror_reservation_rooms  disable row level security;
alter table public.sent_reports              disable row level security;
alter table public.supply_requests           disable row level security;
alter table public.error_logs                disable row level security;
alter table public.push_subscriptions        disable row level security;
alter table public.push_alert_state          disable row level security;
alter table public.dashboard_owners          disable row level security;


-- =========================================================================
-- 7. Refresh du cache PostgREST (sinon l'API renvoie "column not found"
--    pendant ~1 min sur les nouvelles colonnes).
-- =========================================================================
notify pgrst, 'reload schema';


-- =========================================================================
-- BUCKETS STORAGE (à créer à la main dans Supabase → Storage) :
--   - backups   (privé)  → sauvegardes .db quotidiennes
--   - articles  (public) → photos produits + photos chambres
--   - releases  (public) → installeurs .exe + manifest.json
--   - reports   (public) → PDFs de rapports envoyés à Pamela
-- Le SQL ne peut pas les créer proprement, passe par l'UI Storage.
-- =========================================================================

-- Vérif rapide (facultatif) :
--   select table_name from information_schema.tables
--   where table_schema='public' order by table_name;
