# Skyblue — Dashboard propriétaire (Web)

Site web léger permettant à la propriétaire de consulter à distance les
ventes du guesthouse, sans installer l'app locale.

## Ce qu'il fait

- **Connexion** avec les mêmes identifiants que l'application Flutter
  (accès **réservé au Super Admin** — soit la propriétaire).
- **Vue d'ensemble** : chiffre d'affaires, nombre de ventes, panier moyen,
  dettes ouvertes — grands chiffres bien visibles.
- **Sélecteur de période** : aujourd'hui / 7 j / 30 j / 90 j / tout.
- **Graphique** du CA par jour.
- **Top 5 articles** vendus sur la période.
- **15 dernières ventes** avec badge « à crédit » / « réglée » quand
  pertinent.
- **Auto-refresh toutes les 30 s** (donnée toujours fraîche).

Les données viennent des tables `mirror_*` de Supabase — poussées en
temps réel par l'app à chaque vente / mise à jour.

## Créer un compte propriétaire (Supabase uniquement)

Pour un compte qui existe **uniquement dans le cloud** (pas besoin de le
créer via l'app locale) :

1. Ouvre `web_dashboard/tools/create-account.html` dans un navigateur.
2. Remplis : nom, identifiant, mot de passe. L'ID par défaut (9001) est
   volontairement haut pour ne jamais entrer en conflit avec les ids
   auto-incrémentés de l'app locale.
3. Clique **Générer le SQL** → un `INSERT INTO mirror_users` prêt à
   coller apparaît.
4. Va dans Supabase → **SQL Editor** → colle → **Run**.
5. La propriétaire peut immédiatement se connecter au dashboard avec
   ces identifiants.

Le mot de passe n'est jamais envoyé nulle part — le hachage bcrypt se
fait entièrement dans ton navigateur.

## Prérequis Supabase

Les tables `mirror_users`, `mirror_sales`, `mirror_sale_lines`,
`mirror_articles` doivent :

1. **Exister** (déjà fait — l'app les crée / y pousse).
2. Être **lisibles par la clé anon** (par défaut oui si RLS est désactivé).
   Si RLS est activé, ajouter une policy `SELECT` pour `anon` sur ces 4
   tables.

## Lancer en local

Ouvrir simplement `index.html` dans un navigateur moderne (double-clic).

Si le navigateur bloque l'accès aux CDN à cause du protocole `file://`,
lancer un serveur local :

```bash
# Python 3
cd web_dashboard
python -m http.server 8000
# → ouvrir http://localhost:8000
```

## Déployer en ligne (gratuit, 2 minutes)

**Option A — Netlify Drop** (le plus simple)

1. Aller sur https://app.netlify.com/drop
2. Glisser-déposer le dossier `web_dashboard/`
3. URL publique instantanée.

**Option B — Vercel**

```bash
npm i -g vercel
cd web_dashboard
vercel
```

**Option C — Supabase Hosting** (si activé sur ton plan)

Uploader le dossier via le dashboard Supabase → Storage → Buckets publics.

## Sécurité

- Le mot de passe est vérifié **côté navigateur** contre le hash bcrypt
  stocké dans `mirror_users`. Le hash bcrypt est un one-way hash : même
  si un tiers arrive à lire la table `mirror_users` via la clé anon, il
  ne peut pas retrouver le mot de passe.
- **Recommandation** : activer RLS sur `mirror_users` et n'autoriser
  `SELECT` que sur les colonnes non-sensibles (login, full_name, role,
  active), pour ne pas exposer les hashes. Dans ce cas il faudra
  déplacer l'auth vers Supabase Auth (email/mot de passe).
- La session dashboard dure **12 h** (configurable dans `config.js`).

## Modifier

- **URL / clé Supabase** → `config.js`
- **Taux FC → USD** affiché en bas des chiffres → `config.js` (`fcPerUsd`)
- **Auto-refresh** → `config.js` (`refreshMs`, mettre `0` pour désactiver)
- **Palette de couleurs, layout, textes** → `index.html` (Tailwind) et
  `app.js`

## Structure

```
web_dashboard/
├── index.html   Page unique (login + dashboard)
├── config.js    URL / clé Supabase, durée de session, refresh
├── app.js       Logique : auth bcrypt, fetch, agrégations, rendu
└── README.md    Ce fichier
```

Aucune build, aucun bundler, aucune dépendance NPM installée — tout
tourne via CDN (Tailwind, Supabase JS, bcryptjs, Chart.js, Google Fonts).
