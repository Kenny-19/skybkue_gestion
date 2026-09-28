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
à `votre-email@exemple.com` à chaque erreur, il faut un fournisseur d'envoi
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
      to: "votre-email@exemple.com",
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

---

## Comptes utilisateurs — Supabase fait foi (depuis v0.4 / schéma 18)

### Le modèle en trois phrases

1. Les **vrais comptes nominatifs** vivent dans la table Supabase `app_users`.
   Le hash du mot de passe **ne descend jamais** sur un poste.
2. Chaque poste garde un **cache local** (`users`) : il alimente l'écran de
   connexion, et conserve un hash bcrypt du mot de passe **des comptes qui se
   sont déjà connectés sur ce poste** — c'est ce qui autorise la reconnexion
   quand Internet est coupé.
3. Trois **comptes de secours** sont créés à l'installation et ne quittent
   jamais le poste :

   | Identifiant | Code   | Rôle      |
   |-------------|--------|-----------|
   | `reception` | `0000` | Réception |
   | `serveuse`  | `2000` | Serveur   |
   | `admin`     | `7000` | Admin     |

   ⚠️ **Ces codes sont publics** (ils sont dans le code source et connus de
   toute l'équipe). Ils servent à ouvrir l'application le jour de
   l'installation et à dépanner quand le serveur est injoignable. Aucun n'est
   super admin : l'administration réelle passe par un compte Supabase.
   Change-les depuis Réglages → Mot de passe sur chaque poste en production.

### Ce que la sécurité repose vraiment sur

La clé `anon` **n'est pas un secret** : elle est extractible du binaire livré.
La protection vient de la RLS et des fonctions `SECURITY DEFINER` :

* `app_users` n'est lisible par personne avec la clé anon — les hashs restent
  sur le serveur ;
* la liste des comptes passe par la vue `app_users_public` (sans hash) ;
* `bs_verify_login()` compare le mot de passe côté serveur, avec un
  rate-limit de 5 échecs par 5 minutes et par identifiant ;
* **créer, renommer, désactiver ou supprimer un compte exige les identifiants
  d'un admin**, revérifiés dans la fonction. Posséder la clé anon ne suffit
  pas.

### Installation

1. Exécuter `sql/2026_09_comptes_supabase.sql` dans Supabase → SQL Editor.
2. **Modifier le mot de passe du super admin d'amorçage** en bas du fichier
   *avant* de l'exécuter (section 9).
3. Créer les comptes de l'équipe depuis l'app (écran Comptes), connecté avec
   ce super admin.

### Les clés ne sont plus dans le code

Elles sont injectées au build :

```
flutter build windows --release ^
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

`installer/release.ps1` le fait automatiquement en lisant
`installer/supabase.env` (copie de `supabase.env.example`, ignoré par git).
Sans ce fichier, le build produit une application 100 % locale : seuls les
comptes de secours fonctionnent, et l'app le signale au démarrage.

### Ce qui a changé pour l'exploitation

* `mirror_users` n'est plus utilisée. Les comptes ne transitent plus par le
  miroir — c'est ce qui expliquait qu'un compte créé sur un poste **ne
  pouvait pas se connecter sur un autre** (il n'y recevait qu'un hash
  temporaire aléatoire).
* Un compte supprimé sur Supabase disparaît de tous les postes à la
  prochaine synchronisation (bouton *Synchroniser* de l'écran Comptes).
* Dans l'écran Comptes, une pastille **« jamais connecté ici »** indique un
  compte qui ne pourra pas ouvrir l'application hors ligne sur ce poste tant
  qu'il ne s'y sera pas connecté une fois avec Internet.

### Reprise des comptes existants (une seule fois)

Les comptes qui existaient avant la bascule sont dans la base SQLite de
chaque poste. Leur mot de passe y est haché en bcrypt `$2a$` — le format
exact que `crypt()` sait vérifier côté Postgres. On **recopie donc le hash
tel quel** : personne ne change de mot de passe, et aucun mot de passe en
clair ne transite.

Procédure, à faire **une fois**, depuis le poste dont la liste de comptes
fait référence :

1. Exécuter `sql/2026_09_reprise_comptes.sql` dans Supabase → SQL Editor.
2. Générer un jeton (valable 60 min) :

   ```sql
   select public.bs_new_import_token();
   ```

   Un super admin déjà présent sur le serveur peut sauter cette étape :
   sa session suffit à autoriser la reprise.
3. Dans l'app, connecté en super admin : écran **Comptes** → **Reprise vers
   le serveur**. Coller le jeton, vérifier la liste, lancer.
4. Lire le rapport ligne par ligne, puis contrôler côté serveur :

   ```sql
   select login, role, active, left(password_hash, 4) as prefixe
   from   public.app_users order by role, login;

   select public.bs_verify_login('sabrina', 'son-mot-de-passe');
   -- attendu : {"status":"ok", ...}
   ```

5. Sur les **autres postes**, il n'y a rien à reprendre : bouton
   **Synchroniser** de l'écran Comptes, et chaque employé se reconnecte une
   fois avec Internet pour retrouver son accès hors-ligne local.

Ce qui n'est jamais repris, et pourquoi :

| Cas | Raison |
|-----|--------|
| `reception` / `serveuse` / `admin` **créés par l'installeur** | comptes de secours, local par définition |
| Compte sans mot de passe utilisable ici | rien à reprendre (jamais connecté sur ce poste) |
| Login déjà présent sur le serveur | jamais écrasé — relancer la reprise est sans danger |

Sur une installation **existante**, un compte `admin` déjà en service n'est
pas considéré comme un compte de secours : il garde son mot de passe et
fait partie de la reprise. Les comptes de secours manquants (`reception`,
`serveuse`) sont créés à côté.

Le bouton « Reprise vers le serveur » disparaît de lui-même quand plus
aucun compte local n'attend d'être repris.

Après validation sur tous les postes, nettoyer :

```sql
delete from public.app_import_tokens;
-- drop table if exists public.mirror_users;
```
