-- Skyblue — Setup PWA + Push notifications
-- À exécuter UNE FOIS dans Supabase → SQL Editor.

-- 1. Table des abonnements push (un par appareil qui a accepté).
CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  endpoint    text        PRIMARY KEY,
  p256dh      text        NOT NULL,
  auth        text        NOT NULL,
  user_login  text,
  user_agent  text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  last_sent   timestamptz
);

-- 2. Table de traçabilité : sur quels articles a-t-on déjà alerté.
-- Évite d'envoyer 3× la même alerte "Coca en rupture" en 5 min.
CREATE TABLE IF NOT EXISTS public.push_alert_state (
  article_id  integer     PRIMARY KEY,
  last_notified_at timestamptz NOT NULL DEFAULT now(),
  last_qty    integer     NOT NULL DEFAULT 0
);
