// Skyblue — Supabase Edge Function « notify-error »
// Envoie un e-mail (Resend) quand un poste remonte une erreur dans
// `error_logs`.
//
// Remplace la version d'origine (modèle de SUPABASE_SETUP.md), qui avait
// deux défauts, révélés le 5 octobre 2026 :
//   * elle n'affichait PAS le nom du poste, alors que l'app l'envoie : il
//     a fallu interroger la table pour savoir que les erreurs venaient de
//     « Robin » ;
//   * un e-mail par ligne : une base bloquée sur un poste a produit 87
//     e-mails en trente minutes. Resend gratuit plafonne à 100 par jour,
//     une seconde panne le même jour serait passée inaperçue.
//
// Désormais : une alerte par (poste, contexte, erreur) et par heure. Les
// répétitions sont comptées dans la table et annoncées dans l'alerte
// suivante.
//
// À déployer :
//   supabase functions deploy notify-error --no-verify-jwt
//
// Secrets (une fois, via `supabase secrets set`) :
//   RESEND_API_KEY   = clé Resend (déjà en place sur la version actuelle)
//   ALERT_EMAIL_TO   = adresse qui reçoit les alertes
//   SB_URL           = URL du projet (comme stock-alerts)
//   SB_SERVICE_ROLE  = clé service_role (lecture de error_logs)
//
// Déclenchement : inchangé — Database Webhook sur INSERT de error_logs.

// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!;
const ALERT_EMAIL_TO = Deno.env.get('ALERT_EMAIL_TO')!;
const SB_URL = Deno.env.get('SB_URL')!;
const SB_KEY = Deno.env.get('SB_SERVICE_ROLE')!;

const supa = createClient(SB_URL, SB_KEY, {
  auth: { persistSession: false },
});

// Une même erreur d'un même poste ne renvoie pas d'e-mail avant ce délai.
const FENETRE_MS = 60 * 60 * 1000; // 1 h

const premiereLigne = (m: unknown) => String(m ?? '').split('\n')[0].trim();

/** Heure de Lubumbashi (UTC+2), lisible. */
function heureLubumbashi(iso: string): string {
  try {
    return new Date(iso).toLocaleString('fr-FR', {
      timeZone: 'Africa/Lubumbashi',
      dateStyle: 'short',
      timeStyle: 'medium',
    });
  } catch (_) {
    return iso;
  }
}

Deno.serve(async (req) => {
  try {
    const { record } = await req.json();
    if (!record) return new Response('pas de ligne', { status: 400 });

    const poste = record.poste ?? 'poste inconnu';
    const contexte = record.context ?? '—';
    const cle = premiereLigne(record.message);

    // Les erreurs identiques de ce poste dans l'heure qui précède.
    const depuis = new Date(Date.now() - FENETRE_MS).toISOString();
    let requete = supa
      .from('error_logs')
      .select('id, message')
      .gte('occurred_at', depuis)
      .lt('id', record.id)
      .order('id', { ascending: false })
      .limit(1000);
    requete = record.poste == null
      ? requete.is('poste', null)
      : requete.eq('poste', record.poste);
    requete = record.context == null
      ? requete.is('context', null)
      : requete.eq('context', record.context);
    const { data: precedentes, error } = await requete;

    // Si la lecture échoue, on envoie quand même : mieux vaut un e-mail
    // de trop qu'une panne passée sous silence.
    if (!error) {
      const identiques = (precedentes ?? [])
        .filter((r: any) => premiereLigne(r.message) === cle);
      if (identiques.length > 0) {
        return new Response(
          `ignorée : déjà signalée (${identiques.length} dans l'heure)`);
      }
    }

    const lignes = [
      `Poste : ${poste}`,
      `Contexte : ${contexte}`,
      `Version : ${record.app_version ?? '—'}`,
      `Plateforme : ${record.platform ?? '—'}`,
      `Survenu le : ${heureLubumbashi(record.occurred_at)} (Lubumbashi)`,
      '',
      'Message :',
      String(record.message ?? '—'),
      '',
      `Les répétitions de cette erreur sur ce poste ne seront pas signalées `
        + `pendant une heure (elles restent dans la table error_logs).`,
      '',
      'Stack :',
      String(record.stack ?? '—'),
    ];

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'Skyblue <onboarding@resend.dev>',
        to: ALERT_EMAIL_TO,
        // Le poste dans le sujet : on sait d'où vient la panne sans
        // ouvrir l'e-mail.
        subject: `⚠ Skyblue — ${poste} — ${contexte}`,
        text: lignes.join('\n'),
      }),
    });
    if (!res.ok) {
      return new Response(`Resend : ${res.status} ${await res.text()}`, {
        status: 502,
      });
    }
    return new Response('envoyée');
  } catch (e) {
    return new Response(`erreur : ${(e as Error).message}`, { status: 500 });
  }
});
