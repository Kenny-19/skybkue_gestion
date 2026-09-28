-- Multi-postes : compléter mirror_rooms pour que le push depuis Flutter
-- passe sans 400 (colonnes envoyées par _roomJson dans mirror_service.dart).
--
-- À exécuter dans Supabase → SQL Editor. Idempotent : rejouable sans risque.

-- 1. Colonnes manquantes sur mirror_rooms ------------------------------------
alter table public.mirror_rooms
  add column if not exists checkin_note text,
  add column if not exists checkin_at   timestamptz;

-- 2. Filet de sécurité pour les autres colonnes utilisées par le miroir -----
--    (au cas où la table aurait été créée avec un schéma partiel)
alter table public.mirror_rooms
  add column if not exists type                 text,
  add column if not exists price_per_night_cents bigint,
  add column if not exists status               smallint,
  add column if not exists current_guest        text,
  add column if not exists checkout_date        timestamptz;

-- 3. Clé unique sur number (utilisée par onConflict: 'number') --------------
do $$
begin
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public'
      and tablename  = 'mirror_rooms'
      and indexname  = 'mirror_rooms_number_key'
  ) then
    alter table public.mirror_rooms
      add constraint mirror_rooms_number_key unique (number);
  end if;
end$$;

-- 4. Refresh du cache PostgREST (sinon l'API Supabase renvoie encore
--    "column checkin_note not found" pendant ~1 minute).
notify pgrst, 'reload schema';

-- Vérif rapide (facultatif) :
--   select column_name, data_type
--   from   information_schema.columns
--   where  table_schema='public' and table_name='mirror_rooms'
--   order  by ordinal_position;
