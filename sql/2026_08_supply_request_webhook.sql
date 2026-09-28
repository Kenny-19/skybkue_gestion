-- =========================================================================
-- Webhook Postgres → Edge Function supply-request-notify
--
-- À exécuter UNE FOIS dans Supabase → SQL Editor, APRÈS avoir déployé la
-- fonction (`supabase functions deploy supply-request-notify --no-verify-jwt`).
-- =========================================================================

-- Prérequis (déjà installé si stock-alerts fonctionne) :
create extension if not exists pg_net with schema extensions;

-- Fonction trigger : appelée à chaque INSERT dans supply_requests, elle
-- pousse un HTTP POST vers l'Edge Function avec la ligne fraîchement
-- créée sous la clé `record`.
create or replace function public.notify_supply_request()
returns trigger
language plpgsql
security definer
as $$
begin
  perform net.http_post(
    url := 'https://wdwhfgawuozhkeflgcvs.supabase.co/functions/v1/supply-request-notify',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'supply_requests',
      'record', to_jsonb(NEW)
    )
  );
  return NEW;
end;
$$;

-- Trigger : uniquement sur INSERT (pas sur les UPDATE d'approbation).
drop trigger if exists trg_supply_request_notify on public.supply_requests;
create trigger trg_supply_request_notify
  after insert on public.supply_requests
  for each row execute function public.notify_supply_request();

-- Reload cache API.
notify pgrst, 'reload schema';

-- ─────────────────────────────────────────────────────────────────────
-- TEST MANUEL
-- Insère une fausse demande depuis SQL Editor → Pamela reçoit le push.
--
--   insert into public.supply_requests
--     (article_id, article_name, location, qty_requested,
--      qty_at_request, threshold_at_request, requested_by_login, status)
--   values
--     (null, 'TEST DEMANDE HOTEL - draps + savon', 2, 1, 0, 0, 'admin', 'pending');
-- ─────────────────────────────────────────────────────────────────────
