// Skyblue — Supabase Edge Function
// Vérifie les articles sous seuil dans mirror_articles et envoie une
// notification push aux abonnés (table push_subscriptions).
//
// À déployer :
//   supabase functions deploy stock-alerts --no-verify-jwt
//
// Secrets à définir (une fois, via `supabase secrets set`) :
//   SB_URL              = URL du projet Supabase
//   SB_SERVICE_ROLE     = clé service_role (SECRÈTE — jamais côté web)
//   VAPID_PUBLIC_KEY    = clé publique VAPID (identique à config.js)
//   VAPID_PRIVATE_KEY   = clé privée VAPID
//   VAPID_SUBJECT       = "mailto:contact@skyblue-rdc.com" (ou autre email)
//
// Déclenchement : appelée périodiquement par pg_cron OU par un cron
// externe (voir README pour la commande SQL SELECT cron.schedule(...)).

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

// Ne pas re-notifier un même article avant ce délai (millisecondes).
const REMIND_AFTER_MS = 6 * 60 * 60 * 1000; // 6 h

Deno.serve(async (_req) => {
  try {
    // 1. Articles suivis, sous ou égal au seuil.
    const { data: arts, error: e1 } = await supa
      .from('mirror_articles')
      .select('id, name, stock_qty, threshold, track_stock, active')
      .eq('track_stock', true)
      .eq('active', true);
    if (e1) throw e1;
    const lowStock = (arts ?? []).filter(
      (a: any) => (a.threshold ?? 0) > 0 && (a.stock_qty ?? 0) <= a.threshold,
    );

    if (lowStock.length === 0) {
      return json({ ok: true, sent: 0, note: 'Rien à alerter.' });
    }

    // 2. Filtre : ne pas re-alerter si déjà notifié récemment.
    const { data: states } = await supa
      .from('push_alert_state')
      .select('article_id, last_notified_at, last_qty');
    const stateById: Record<number, any> = {};
    for (const s of states ?? []) stateById[s.article_id] = s;

    const now = Date.now();
    const toNotify = lowStock.filter((a: any) => {
      const s = stateById[a.id];
      if (!s) return true;
      const elapsed = now - new Date(s.last_notified_at).getTime();
      if (elapsed >= REMIND_AFTER_MS) return true;
      // Ou : nouvelle baisse depuis la dernière notif.
      if (a.stock_qty < s.last_qty) return true;
      return false;
    });

    if (toNotify.length === 0) {
      return json({
        ok: true,
        sent: 0,
        note: 'Alertes déjà envoyées récemment.',
      });
    }

    // 3. Message payload.
    const title = 'Skyblue — Stock bas';
    const bodyLines = toNotify.slice(0, 5).map(
      (a: any) => `• ${a.name} : ${a.stock_qty}/${a.threshold}`,
    );
    if (toNotify.length > 5) {
      bodyLines.push(`… et ${toNotify.length - 5} autre(s)`);
    }
    const body = bodyLines.join('\n');
    const payload = JSON.stringify({
      title,
      body,
      tag: 'skyblue-stock',
      url: '/',
    });

    // 4. Récupère tous les abonnés et envoie.
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
        // 404/410 → abonnement mort (utilisateur a désinstallé)
        const status = err?.statusCode ?? 0;
        if (status === 404 || status === 410) {
          deadEndpoints.push(s.endpoint);
        } else {
          console.warn('push failed for endpoint', s.endpoint, err);
        }
      }
    }

    // 5. Nettoyage des abonnements morts.
    if (deadEndpoints.length > 0) {
      await supa
        .from('push_subscriptions')
        .delete()
        .in('endpoint', deadEndpoints);
    }

    // 6. Sauvegarde de l'état pour anti-spam.
    const upserts = toNotify.map((a: any) => ({
      article_id: a.id,
      last_notified_at: new Date().toISOString(),
      last_qty: a.stock_qty,
    }));
    await supa.from('push_alert_state').upsert(upserts, {
      onConflict: 'article_id',
    });

    return json({
      ok: true,
      sent,
      articles: toNotify.length,
      cleaned: deadEndpoints.length,
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
