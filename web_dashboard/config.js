// Configuration Supabase — mêmes valeurs que lib/core/cloud_config.dart.
// Modifier ici si l'URL ou la clé anon changent côté Supabase.
window.SKYBLUE_CONFIG = {
  supabaseUrl: 'https://wdwhfgawuozhkeflgcvs.supabase.co',
  supabaseAnonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indkd2hmZ2F3dW96aGtlZmxnY3ZzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY5NDcwNDgsImV4cCI6MjEwMjUyMzA0OH0.Bz1Wt-3h8AYsR59vPPzKTakxJvTf9BXhQ7Bei4cbAvU',
  // Taux FC → USD pour l'affichage indicatif « ≈ $X ».
  //
  // ⚠ DOIT correspondre au taux réglé dans l'application (Réglages →
  //   taux de change). Il valait 2800 ici et 2300 là-bas : les mêmes
  //   montants donnaient deux chiffres différents selon l'écran, et
  //   personne ne pouvait dire lequel était le bon.
  //
  //   Une valeur recopiée à la main finit toujours par diverger. La
  //   corriger ne fait que remettre les pendules à l'heure — voir plus
  //   bas pour la vraie solution.
  fcPerUsd: 2300,
  // Session : durée avant re-login automatique (millisecondes).
  sessionTtlMs: 12 * 60 * 60 * 1000, // 12h
  // Auto-refresh du dashboard (ms). 0 = désactivé.
  refreshMs: 30000,
  // Clé publique VAPID pour les Web Push (générée avec `web-push`).
  // La clé privée reste côté serveur (Supabase Edge Function).
  vapidPublicKey:
    'BA1gsNrFkksQpW1Ua3wpY55eSoRtcEHLQcRZrsLjuZffyTXy29rVim3u7swqJXDFqWdOmoExEdhCqgX76cy2NbQ',
};
