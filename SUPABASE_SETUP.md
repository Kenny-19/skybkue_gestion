# Configuration Supabase — Skyblue

À faire **une seule fois** dans ton dashboard Supabase. Tout l'app est déjà branché.

---

## Étape 1 — Buckets de stockage (si pas déjà fait)

SQL Editor → New query → colle → **Run** :

```sql
insert into storage.buckets (id, name, public)
values ('articles', 'articles', true),
       ('backups',  'backups',  false)
on conflict (id) do nothing;

drop policy if exists "app anon articles" on storage.objects;
drop policy if exists "app anon backups"  on storage.objects;

create policy "app anon articles" on storage.objects
  for all to anon using (bucket_id = 'articles') with check (bucket_id = 'articles');
create policy "app anon backups" on storage.objects
  for all to anon using (bucket_id = 'backups') with check (bucket_id = 'backups');
```

---

## Étape 2 — Tables miroir + journal d'erreurs

SQL Editor → New query → colle **tout** → **Run** :

```sql
-- ─── Tables miroir (copie consultable des données locales) ───────────────
create table if not exists mirror_articles (
  id integer primary key,
  name text, price_cents integer, category integer, active boolean,
  track_stock boolean, unit text, stock_qty integer, threshold integer,
  image_path text, synced_at timestamptz default now()
);

create table if not exists mirror_rooms (
  number text primary key,
  type text, price_per_night_cents integer, status integer,
  current_guest text, checkout_date timestamptz, synced_at timestamptz default now()
);

create table if not exists mirror_users (
  id integer primary key,
  full_name text, login text, role integer, active boolean,
  created_at timestamptz, last_login timestamptz, synced_at timestamptz default now()
);

create table if not exists mirror_sales (
  id integer primary key,
  sold_at timestamptz, server_user_id integer, payment integer,
  location integer, customer_name text, note text, synced_at timestamptz default now()
);

create table if not exists mirror_sale_lines (
  id integer primary key,
  sale_id integer, article_id integer, article_name text,
  qty integer, unit_price_cents integer, synced_at timestamptz default now()
);

-- ─── Journal des erreurs de l'app ────────────────────────────────────────
create table if not exists error_logs (
  id bigint generated always as identity primary key,
  message text, stack text, context text,
  app_version text, platform text,
  occurred_at timestamptz, created_at timestamptz default now()
);

-- ─── Droits pour la clé anon (l'app) ─────────────────────────────────────
alter table mirror_articles   enable row level security;
alter table mirror_rooms      enable row level security;
alter table mirror_users      enable row level security;
alter table mirror_sales      enable row level security;
alter table mirror_sale_lines enable row level security;
alter table error_logs        enable row level security;

do $$
declare t text;
begin
  foreach t in array array[
    'mirror_articles','mirror_rooms','mirror_users',
    'mirror_sales','mirror_sale_lines','error_logs'
  ] loop
    execute format('drop policy if exists "anon all %1$s" on %1$s;', t);
    execute format(
      'create policy "anon all %1$s" on %1$s for all to anon using (true) with check (true);', t);
  end loop;
end $$;
```

Après ça : dans l'app → **Paramètres → Stockage cloud → Synchroniser les données**.
Tes ventes/produits apparaîtront dans **Table Editor → mirror_sales**, etc.

---

## Étape 3 — Email sur erreur (optionnel)

L'app enregistre déjà les erreurs dans `error_logs`. Pour **recevoir un email**
à `kennytshibangu9@gmail.com` à chaque erreur, il faut un fournisseur d'envoi
(l'app ne peut pas envoyer d'email elle-même, pour des raisons de sécurité).

Le plus simple : **Resend** (gratuit jusqu'à 100 emails/jour).

1. Crée un compte sur https://resend.com → récupère une **API Key**.
2. Supabase → **Edge Functions** → New function `notify-error` → colle :

```ts
import { serve } from "https://deno.land/std/http/server.ts";

serve(async (req) => {
  const { record } = await req.json();
  await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${Deno.env.get("RESEND_API_KEY")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "Skyblue <onboarding@resend.dev>",
      to: "kennytshibangu9@gmail.com",
      subject: `⚠ Erreur Skyblue — ${record.platform}`,
      text: `Contexte : ${record.context}\n`
          + `Message : ${record.message}\n`
          + `Version : ${record.app_version}\n`
          + `Heure : ${record.occurred_at}\n\n`
          + `Stack :\n${record.stack ?? "—"}`,
    }),
  });
  return new Response("ok");
});
```

3. Déploie, puis ajoute le secret :
   Edge Functions → notify-error → Settings → Secrets → `RESEND_API_KEY = ta_clé`
4. Branche le déclenchement : **Database → Webhooks → Create**
   - Table : `error_logs` · Événement : `Insert`
   - Type : `Supabase Edge Function` → `notify-error`

Dès qu'une erreur survient dans l'app, tu reçois un email. Tant que tu ne fais
pas cette étape 3, les erreurs restent quand même visibles dans la table
`error_logs` du dashboard.

---

## Récap de ce qui marche

| Fonction | Où voir |
|---|---|
| Photos produits | bucket `articles` |
| Sauvegarde .db quotidienne (00:00) | bucket `backups/` |
| Ventes / produits en clair | tables `mirror_*` (Table Editor) |
| Erreurs de l'app | table `error_logs` (+ email si étape 3) |

L'app reste **100% fonctionnelle hors ligne** — tout ceci se synchronise
uniquement quand il y a du réseau.
