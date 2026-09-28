-- =========================================================================
-- Webhook Postgres → Edge Function sent-report-notify
--
-- À exécuter dans Supabase → SQL Editor APRÈS avoir déployé la fonction :
--   supabase functions deploy sent-report-notify --no-verify-jwt
-- =========================================================================

create extension if not exists pg_net with schema extensions;

create or replace function public.notify_sent_report()
returns trigger
language plpgsql
security definer
as $$
begin
  perform net.http_post(
    url := 'https://wdwhfgawuozhkeflgcvs.supabase.co/functions/v1/sent-report-notify',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'sent_reports',
      'record', to_jsonb(NEW)
    )
  );
  return NEW;
end;
$$;

drop trigger if exists trg_sent_report_notify on public.sent_reports;
create trigger trg_sent_report_notify
  after insert on public.sent_reports
  for each row execute function public.notify_sent_report();

notify pgrst, 'reload schema';

-- ─────────────────────────────────────────────────────────────────────
-- TEST MANUEL :
--   insert into public.sent_reports
--     (name, period, kind, storage_path, public_url, generated_by_login)
--   values
--     ('TEST rapport', 'Aujourd''hui', 'summary',
--      'reports/test.pdf', 'https://example.com/test.pdf', 'admin');
-- ─────────────────────────────────────────────────────────────────────
