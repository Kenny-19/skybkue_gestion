// Skyblue — Supabase Edge Function
// Push notification à Pamela dès qu'un rapport PDF est envoyé depuis
// l'app (INSERT dans sent_reports).
//
// Déploiement :
//   supabase functions deploy sent-report-notify --no-verify-jwt
//
// Secrets requis (partagés avec les autres functions) :
//   SB_URL, SB_SERVICE_ROLE, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT

// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import webpush from 'https://esm.sh/web-push@3.6.7';

const SB_URL = Deno.env.get('SB_URL')!;
const SB_KEY = Deno.env.get('SB_SERVICE_ROLE')!;
const VAPID_PUBLIC = Deno.env.get('VAPID_PUBLIC_KEY')!;
const VAPID_PRIVATE = Deno.env.get('VAPID_PRIVATE_KEY')!;
const VAPID_SUBJECT =
  Deno.env.get('VAPID_SUBJECT') ?? 'mailto:contact@skyblue-rdc.com';

webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE);

const supa = createClient(SB_URL, SB_KEY, {
  auth: { persistSession: false },
});

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return json({ ok: false, error: 'POST only' }, 405);
    }
    const body = await req.json().catch(() => ({}));
    const rec = body?.record ?? body;
    if (!rec || typeof rec !== 'object') {
      return json({ ok: false, error: 'no record' }, 400);
    }

    const name = String(rec.name ?? 'Rapport');
    const period = String(rec.period ?? '');
    const by = String(rec.generated_by_login ?? 'inconnu');
    const size = Number(rec.size_bytes ?? 0);
    const kb = size > 0 ? `${Math.round(size / 1024)} Ko` : '';

    const title = 'Nouveau rapport reçu';
    const bodyText = [
      name,
      period ? `Période : ${period}` : null,
      `De ${by}${kb ? ` · ${kb}` : ''}`,
    ]
      .filter(Boolean)
      .join('\n');

    const payload = JSON.stringify({
      title,
      body: bodyText,
      tag: `sent-report-${rec.id ?? Date.now()}`,
      url: '/#reports',
    });

    const { data: subs, error: e2 } = await supa
      .from('push_subscriptions')
      .select('*');
    if (e2) throw e2;
    if (!subs || subs.length === 0) {
      return json({ ok: true, sent: 0, note: 'Aucun abonné.' });
    }

    let sent = 0;
    const dead: string[] = [];
    for (const s of subs) {
      try {
        await webpush.sendNotification(
          { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
          payload,
        );
        sent++;
      } catch (err: any) {
        const st = err?.statusCode ?? 0;
        if (st === 404 || st === 410) dead.push(s.endpoint);
        else console.warn('push failed', s.endpoint, err);
      }
    }
    if (dead.length > 0) {
      await supa
        .from('push_subscriptions')
        .delete()
        .in('endpoint', dead);
    }
    return json({ ok: true, sent, subs: subs.length, cleaned: dead.length });
  } catch (e: any) {
    console.error(e);
    return json({ ok: false, error: String(e?.message ?? e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}
