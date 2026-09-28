-- Système de remise complet (app v17) : tarif négocié par chambre au
-- check-in + détail de la remise de facturation au check-out.
--
-- À exécuter dans Supabase → SQL Editor AVANT de déployer la version
-- Flutter correspondante. Idempotent : rejouable sans risque.
--
-- Note importante
-- ---------------
-- Seule `mirror_rooms` est réellement utilisée aujourd'hui : l'app ne
-- pousse PAS les séjours vers le cloud (les fonctions _stayJson /
-- _stayRoomJson de mirror_service.dart ne sont appelées nulle part).
-- Les blocs concernant `mirror_stays` / `mirror_stay_rooms` ne
-- s'exécutent donc que si ces tables existent déjà — sinon ils sont
-- ignorés proprement au lieu de faire échouer le script.

-- ── 1. Tarif négocié pour le séjour en cours (table utilisée) ──────────
alter table public.mirror_rooms
  add column if not exists negotiated_price_cents bigint;

-- ── 2. Détail de la remise, SI le miroir des séjours existe ────────────
--     remise_cents reste la source de vérité comptable ; les colonnes
--     ci-dessous expliquent comment ce montant a été obtenu.
do $$
begin
  if to_regclass('public.mirror_stays') is not null then
    alter table public.mirror_stays
      add column if not exists remise_kind   smallint default 0,  -- 0=montant, 1=%
      add column if not exists remise_value  bigint   default 0,  -- cents FC ou centièmes de %
      add column if not exists remise_base   smallint default 1,  -- 0=hébergement, 1=total
      add column if not exists remise_reason text;

    -- Reprise des séjours déjà archivés : l'ancienne remise était
    -- toujours un montant fixe.
    update public.mirror_stays
       set remise_value = remise_cents
     where remise_cents > 0 and coalesce(remise_value, 0) = 0;

    raise notice 'mirror_stays : colonnes de remise ajoutées.';
  else
    raise notice 'mirror_stays absente — ignorée (les séjours ne sont pas miroités).';
  end if;

  if to_regclass('public.mirror_stay_rooms') is not null then
    alter table public.mirror_stay_rooms
      add column if not exists list_price_cents bigint;
    raise notice 'mirror_stay_rooms : list_price_cents ajoutée.';
  else
    raise notice 'mirror_stay_rooms absente — ignorée.';
  end if;
end$$;

-- ── 3. Refresh du cache PostgREST ─────────────────────────────────────
notify pgrst, 'reload schema';

-- Vérification (facultatif) :
--   select column_name from information_schema.columns
--    where table_schema = 'public' and table_name = 'mirror_rooms'
--      and column_name = 'negotiated_price_cents';
