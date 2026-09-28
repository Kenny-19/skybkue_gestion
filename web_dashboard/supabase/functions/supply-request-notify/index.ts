// Skyblue — Supabase Edge Function
// Envoie un push web à Pamela dès qu'une nouvelle demande de
// ravitaillement est INSÉRÉE dans supply_requests.
//
// Appelée par un trigger Postgres (voir sql/2026_08_supply_request_webhook.sql)
// qui fait un net.http_post vers cette fonction avec le payload
// { record: {...la ligne insérée...} }.
//
// À déployer :
//   supabase functions deploy supply-request-notify --no-verify-jwt
//
// Secrets requis (déjà définis pour stock-alerts) :
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

// Correspondance index → libellé location (identique côté Flutter :
// enum DbLocation { restaurant, terrasse, hotel }).
const LOCATION_LABELS = ['Restaurant', 'Terrasse', 'Hôtel'];

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return json({ ok: false, error: 'POST only' }, 405);
    }
    const body = await req.json().catch(() => ({}));
    // Payload Supabase Database Webhook OU trigger custom :
    //   { type: 'INSERT', table: 'supply_requests', record: {...} }
    // On accepte aussi un appel manuel avec juste `record`.
    const rec = body?.record ?? body;
    if (!rec || typeof rec !== 'object') {
      return json({ ok: false, error: 'no record in payload' }, 400);
    }

    const status = String(rec.status ?? 'pending');
    if (status !== 'pending') {
      // Le trigger est sur INSERT uniquement, mais par sécurité on ignore
      // toute demande qui arriverait déjà décidée.
      return json({ ok: true, skipped: true, reason: `status=${status}` });
    }

    const articleName = String(rec.article_name ?? 'Ravitaillement');
    const qty = Number(rec.qty_requested ?? 1);
    const locIdx = Number(rec.location ?? 0);
    const locLabel = LOCATION_LABELS[locIdx] ?? 'Poste';
    const by = String(rec.requested_by_login ?? 'un serveur');
    const isHotelNote = rec.article_id == null && locIdx === 2;

    // Compose titre + corps.
    const title = isHotelNote
      ? `Nouvelle demande — Hôtel`
      : `Nouvelle demande — ${locLabel}`;
    const body_ = isHotelNote
      ? // Pour les notes hôtel, article_name contient le texte tronqué.
        `« ${articleName} »\nDe ${by}`
      : `${qty}× ${articleName}\nDe ${by} (${locLabel})`;

    const payload = JSON.stringify({
      title,
      body: body_,
      // Tag unique par demande pour ne pas écraser la précédente.
      tag: `supply-req-${rec.id ?? Date.now()}`,
      url: '/', // Le dashboard écoutera les clics
    });

    // Envoi à tous les abonnés.
    const { data: subs, error: e2 } = await supa
      .from('push_subscriptions')
      .select('*');
    if (e2) throw e2;
    if (!subs || subs.length === 0) {
      return json({ ok: true, sent: 0, note: 'Aucun abonné.' });
    }

    let sent = 0;
    const deadEndpoints: string[] = [];
    for (const s of subs) {
      try {
        await webpush.sendNotification(
          {
            endpoint: s.endpoint,
            keys: { p256dh: s.p256dh, auth: s.auth },
          },
          payload,
        );
        sent++;
      } catch (err: any) {
        const st = err?.statusCode ?? 0;
        if (st === 404 || st === 410) {
          deadEndpoints.push(s.endpoint);
        } else {
          console.warn('push failed', s.endpoint, err);
        }
      }
    }

    if (deadEndpoints.length > 0) {
      await supa
        .from('push_subscriptions')
        .delete()
        .in('endpoint', deadEndpoints);
    }

    return json({
      ok: true,
      sent,
      subs: subs.length,
      cleaned: deadEndpoints.length,
      request_id: rec.id ?? null,
    });
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
