# Skyblue — Guide PWA + Notifications push

Ce document explique comment activer les **notifications push d'alerte
stock** pour Pamela sur son iPhone (ou Android). À faire une seule fois.

## Vue d'ensemble

```
[Pamela ouvre le site Netlify]
        ↓
Elle clique "Activer les alertes"
        ↓
Le navigateur enregistre son appareil dans push_subscriptions
        ↓
Toutes les X heures : Edge Function stock-alerts
   - lit mirror_articles WHERE stock_qty ≤ threshold
   - envoie une notification push à chaque abonné
        ↓
🔔 iPhone / Android reçoit "Coca 33cl : 2/24 restant"
```

## 1. Déployer le site sur Netlify (HTTPS obligatoire)

Le service worker et les push notifications **ne fonctionnent PAS**
en `file://` ou en HTTP simple.

**Méthode la plus simple — Netlify Drop** :

1. Aller sur https://app.netlify.com/drop
2. Glisser-déposer le dossier `web_dashboard/` entier.
3. Netlify te donne une URL type `https://random.netlify.app`.
4. (Optionnel) Renommer le site depuis l'admin Netlify pour avoir une
   URL personnalisée type `https://skyblue-pamela.netlify.app`.

## 2. Créer les tables Supabase (une fois)

Va dans Supabase → SQL Editor → colle :

```sql
CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  endpoint    text        PRIMARY KEY,
  p256dh      text        NOT NULL,
  auth        text        NOT NULL,
  user_login  text,
  user_agent  text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  last_sent   timestamptz
);

CREATE TABLE IF NOT EXISTS public.push_alert_state (
  article_id  integer     PRIMARY KEY,
  last_notified_at timestamptz NOT NULL DEFAULT now(),
  last_qty    integer     NOT NULL DEFAULT 0
);
```

## 3. Déployer la fonction Edge stock-alerts

Prérequis : installer la CLI Supabase (`brew install supabase/tap/supabase`
ou `scoop install supabase` sur Windows).

```bash
cd web_dashboard

# Se connecter et lier au projet.
supabase login
supabase link --project-ref wdwhfgawuozhkeflgcvs

# Définir les secrets (une fois).
supabase secrets set \
  SB_URL="https://wdwhfgawuozhkeflgcvs.supabase.co" \
  SB_SERVICE_ROLE="<colle-ta-cle-service-role-ici>" \
  VAPID_PUBLIC_KEY="BA1gsNrFkksQpW1Ua3wpY55eSoRtcEHLQcRZrsLjuZffyTXy29rVim3u7swqJXDFqWdOmoExEdhCqgX76cy2NbQ" \
  VAPID_PRIVATE_KEY="9etD7YVMihvShFBqMS6o1h9tgZmow5F5Hv8uq8nhG-8" \
  VAPID_SUBJECT="mailto:contact@skyblue-rdc.com"

# Déployer la fonction.
supabase functions deploy stock-alerts --no-verify-jwt
```

Où trouver la **service_role key** : Supabase → Project Settings → API →
"Project API keys" → `service_role` (secret / admin). **Ne jamais**
la mettre dans `config.js` ou côté navigateur.

## 4. Programmer l'exécution automatique

Deux options — l'une des deux suffit.

### Option A — pg_cron (dans Supabase, gratuit)

Dans Supabase → SQL Editor :

```sql
-- Active pg_cron (à faire une fois).
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Toutes les 30 minutes, appelle la fonction Edge stock-alerts.
SELECT cron.schedule(
  'stock-alerts-30min',
  '*/30 * * * *',
  $$
    SELECT net.http_post(
      url := 'https://wdwhfgawuozhkeflgcvs.supabase.co/functions/v1/stock-alerts',
      headers := jsonb_build_object('Content-Type','application/json')
    );
  $$
);
```

### Option B — Cron externe (gratuit)

- **UptimeRobot** (https://uptimerobot.com) : ajoute un monitor HTTP(s)
  qui pingue toutes les 5 min l'URL de la fonction. Chaque ping =
  1 vérification stock.
- Ou **cron-job.org** — même principe.

URL à pinger :
`https://wdwhfgawuozhkeflgcvs.supabase.co/functions/v1/stock-alerts`

## 5. Côté Pamela : installer la PWA + activer les alertes

### Sur iPhone (iOS 16.4+)

1. Ouvrir Safari, aller sur l'URL du site Netlify.
2. Se connecter (login `pamela`, mot de passe `002026`).
3. **Icône Partager** (en bas) → **Sur l'écran d'accueil**.
4. Ouvrir l'app depuis l'écran d'accueil (icône Skyblue).
5. Cliquer **Activer les alertes** en haut à droite.
6. Autoriser les notifications quand iOS demande.
7. C'est fini. Elle reçoit un push de test "Alertes activées".

**Sans étape 3 (installation), les notifs ne marcheront PAS sur iPhone.**

### Sur Android (Chrome)

1. Ouvrir l'URL Netlify.
2. Se connecter.
3. Chrome propose "Ajouter à l'écran d'accueil" (bannière ou menu ⋮).
4. Cliquer **Activer les alertes**.
5. Autoriser.

## 6. Tester une alerte manuellement

Depuis Supabase → SQL Editor :

```sql
-- Forcer le stock de Coca à 1 pour déclencher une alerte.
UPDATE mirror_articles SET stock_qty = 1 WHERE name = 'Coca Cola 33cl';
```

Puis, dans SQL Editor :

```sql
-- Appel manuel de la fonction Edge.
SELECT net.http_post(
  url := 'https://wdwhfgawuozhkeflgcvs.supabase.co/functions/v1/stock-alerts',
  headers := jsonb_build_object('Content-Type','application/json')
);
```

En moins de 5 secondes, Pamela doit recevoir la notification.

## Ce qui empêche le spam

- **Délai anti-répétition** : un article déjà notifié ne l'est plus
  pendant **6 h**, sauf si son stock a **encore baissé** depuis
  (nouvelle vente qui aggrave la situation). Réglable dans
  `supabase/functions/stock-alerts/index.ts` (variable `REMIND_AFTER_MS`).
- **Regroupement** : une seule notification liste jusqu'à 5 articles
  concernés. Au-delà, résumé "… et N autre(s)".
- **Nettoyage auto** : si un endpoint est mort (Pamela a désinstallé
  la PWA), il est supprimé automatiquement de `push_subscriptions`.

## Sécurité et rôles

- La **clé publique VAPID** est dans `config.js` (peut être publique).
- La **clé privée VAPID** vit uniquement dans les secrets Supabase Edge
  Function, jamais dans le repo ni côté navigateur.
- La **service_role key** aussi — ne l'inclus JAMAIS dans le repo
  publié sur Netlify.
- Le fichier `service-worker.js` est chargé automatiquement par
  `index.html` (via `navigator.serviceWorker.register`).

## Fichiers concernés

```
web_dashboard/
├── manifest.webmanifest             ← PWA
├── service-worker.js                ← cache + push handler
├── icons/                           ← icônes PWA (192x192, 512x512)
├── config.js                        ← + clé publique VAPID
├── index.html                       ← + lien manifest + meta iOS
├── app.js                           ← + bouton "Activer les alertes"
└── supabase/
    ├── schema.sql                   ← tables push_*
    └── functions/stock-alerts/
        └── index.ts                 ← Edge Function
```
