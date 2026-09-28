# Analyse de sécurité — Skyblue Guest House

Revue effectuée sur l'ensemble de l'app (auth, base locale, Supabase, fichiers,
permissions). Classée par gravité. Chaque point a un correctif concret.

---

## 🟢 Ce qui est BIEN fait

- **Mots de passe hachés bcrypt** — jamais stockés en clair, salt automatique.
- **Zéro injection SQL** — Drift utilise des requêtes paramétrées ; les rares
  `customStatement` (migrations) sont statiques, sans entrée utilisateur.
- **Pas de clé `service_role` dans l'app** — seulement la clé `anon` (publiable).
- **Identifiants email hors de l'app** — l'envoi se fait côté Supabase.
- **Offline-first robuste** — le reporting/cloud ne fait jamais planter l'app.
- **Session en mémoire** — vidée à la déconnexion, pas de jeton persistant.

---

## 🔴 CRITIQUE — à corriger avant déploiement réel

### C1. Permissions Supabase trop ouvertes (lecture des données par n'importe qui)
Les politiques actuelles sont `to anon using(true) with check(true)` sur toutes
les tables `mirror_*` et `error_logs`. Or **la clé anon est embarquée dans le
.exe distribué** et s'extrait en 2 minutes. Conséquence : **toute personne qui
récupère l'exe peut LIRE toutes les ventes, tous les utilisateurs (noms,
logins, rôles) et tout l'historique** directement via l'API REST Supabase.

**Correctif** — passer les tables en *écriture seule* pour anon (la consultation
se fait dans le dashboard avec TES identifiants, pas via la clé anon) :

```sql
-- error_logs : insertion seule, pas de lecture
drop policy if exists "anon all error_logs" on error_logs;
create policy "anon insert error_logs" on error_logs
  for insert to anon with check (true);

-- mirror_* : insertion + mise à jour (pour upsert), PAS de lecture ni suppression
do $$
declare t text;
begin
  foreach t in array array[
    'mirror_articles','mirror_rooms','mirror_users','mirror_sales','mirror_sale_lines'
  ] loop
    execute format('drop policy if exists "anon all %1$s" on %1$s;', t);
    execute format('create policy "ins %1$s" on %1$s for insert to anon with check (true);', t);
    execute format('create policy "upd %1$s" on %1$s for update to anon using (true) with check (true);', t);
  end loop;
end $$;
```

Après ça : plus personne ne peut *lire* tes données avec la clé anon, mais l'app
continue de *pousser* normalement. Tu consultes toujours dans le Table Editor.

### C2. Le bucket `backups` contient toute la base — téléchargeable par anon
Le fichier `.db` sauvegardé contient **tous les utilisateurs, les hachages de
mots de passe, toutes les ventes**. Avec la politique actuelle, quiconque a la
clé anon peut **télécharger la base entière** puis casser les mots de passe
bcrypt hors ligne à sa vitesse.

**Correctif** — autoriser l'upload mais **interdire le téléchargement/listing**
par anon (la restauration se fera par toi via le dashboard) :

```sql
drop policy if exists "app anon backups" on storage.objects;
create policy "anon insert backups" on storage.objects
  for insert to anon with check (bucket_id = 'backups');
```

⚠️ Effet de bord : le bouton "Restaurer depuis le cloud" ne marchera plus avec
la clé anon (il faut une lecture). Pour restaurer : télécharge le `.db` depuis
le dashboard Supabase (Storage → backups) et utilise "Restaurer une sauvegarde"
en local. Rare et réservé au super admin — acceptable.

### C3. Compte par défaut admin / bluesky
Identifiant super admin connu et faible. Si non changé au déploiement =
accès total trivial.

**Correctif** : **changer le mot de passe dès la première connexion**
(Paramètres → Mon mot de passe). Idéalement forcer le changement au 1er login
(amélioration future). Documenté mais non imposé aujourd'hui.

---

## 🟠 ÉLEVÉ

### E1. Base locale non chiffrée
`Documents/BlueSky/blue_sky.db` est lisible par quiconque a accès au PC (clé
USB, session Windows non verrouillée). Les mots de passe sont hachés (bon) mais
toutes les ventes/clients sont en clair.

**Correctif** : chiffrer la base avec SQLCipher (`sqlcipher_flutter_libs` +
clé dérivée). Ou, a minima : compte Windows protégé + disque BitLocker sur le
poste caisse. Recommandé si le PC n'est pas physiquement sécurisé.

### E2. Clé anon + config dans le dépôt Git
`lib/core/cloud_config.dart` (avec l'URL et la clé anon) est commité. Si le
dépôt devient public ou est partagé, la clé fuite. Elle est "publiable" mais,
combinée à C1/C2, elle ouvre tout.

**Correctif** : une fois C1/C2 appliqués, le risque retombe (anon = écriture
seule). Sinon, passer par `--dart-define=SUPABASE_ANON_KEY=...` au build
(le code le supporte déjà via `String.fromEnvironment`) et retirer la valeur
par défaut du fichier.

### E3. Politique de mot de passe faible
La création d'utilisateur accepte un mot de passe d'**1 caractère**
(`pwd.text.isEmpty` seulement). Le changement en Paramètres exige 4 caractères.

**Correctif** : imposer un minimum (8 caractères) à la création ET au
changement. Petite modif, à faire.

---

## 🟡 MOYEN

### M1. Fuite potentielle de données dans les logs d'erreur
`error_logs` reçoit `message` + `stack`. Une exception peut contenir des données
(nom client, contenu de requête). Combiné à C1 (lisible par anon) = fuite.

**Correctif** : C1 ferme la lecture. En plus, éviter de logger des objets
métier bruts (déjà le cas — on logge `error.toString()`).

### M2. `mirror_users` expose logins et rôles
Pas de hash (bon), mais les logins et rôles permettent de cibler des attaques
(on sait qui est admin). Fermé par C1 (plus de lecture anon).

### M3. Bucket `articles` public + upload de n'importe quel type
Les images sont en lecture publique (nécessaire pour l'affichage), mais anon
peut aussi y écrire/écraser. Un tiers pourrait héberger du contenu arbitraire.

**Correctif** (optionnel) : restreindre l'upload à `insert` seul (pas d'écrasement)
et valider l'extension côté app (déjà limité à jpg/png/webp dans le picker).

---

## 🔵 FAIBLE

- **F1. Pas de limite de tentatives de connexion** — brute force théorique, mais
  l'app est locale (pas d'API login exposée). Risque faible.
- **F2. Fraîcheur des dépendances** — lancer `flutter pub outdated` et mettre à
  jour périodiquement (supabase, drift, pdf).
- **F3. `anonKey` déprécié** — migrer vers `publishableKey` à terme (cosmétique).

---

## Ordre d'action recommandé

1. **C1 + C2** (SQL ci-dessus) — 5 minutes, ferme les deux plus gros trous.
2. **C3** — changer le mot de passe admin maintenant.
3. **E3** — imposer 8 caractères minimum (petite modif code).
4. **E1** — chiffrer la base si le poste n'est pas physiquement sûr.
5. Le reste selon le contexte.

Les points C1, C2, C3 suffisent à passer d'un niveau "exposé" à "raisonnablement
sûr pour un usage local en petit établissement".
