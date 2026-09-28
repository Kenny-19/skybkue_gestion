# Skyblue — Packaging & Release à distance

Ce dossier contient tout ce qu'il faut pour packager Skyblue en installeur
Windows et publier des mises à jour à distance que Pamela reçoit
automatiquement dans l'app.

## Contenu

| Fichier | Rôle |
|---|---|
| `skyblue.nsi` | Script NSIS — définit l'installeur (chemins, raccourcis, désinstalleur) |
| `release.ps1` | Script "tout-en-un" — build Flutter + packaging NSIS + hash + manifest |
| `app_icon.ico` | Icône de l'installeur et de l'app (copiée de `windows/runner/resources/`) |
| `manifest.json` | Généré par `release.ps1` — décrit la version à Pamela |
| `skyblue-setup-*.exe` | Généré par `release.ps1` — l'installeur final |

## Setup initial (à faire une fois)

### 1. Installer NSIS

```powershell
# Via Scoop (recommandé) :
scoop install nsis

# OU télécharger l'installeur depuis :
# https://nsis.sourceforge.io/Download
```

Vérifie :
```powershell
makensis /VERSION
# Doit afficher : v3.09 ou plus récent
```

### 2. Créer le bucket Supabase

1. Dashboard Supabase → **Storage** → **New bucket**
2. Nom : `releases`
3. **Public bucket** : ✅ activé (Pamela doit pouvoir télécharger sans auth)
4. Créer

Le bucket est accessible via :
```
https://wdwhfgawuozhkeflgcvs.supabase.co/storage/v1/object/public/releases/<fichier>
```

### 3. Ajouter la clé Supabase dans le script (déjà fait)

Le script `release.ps1` a déjà l'URL de ton projet Supabase en dur (ligne
`$supabaseBase`). Si tu changes de projet, modifie cette ligne.

## Publier une nouvelle version (workflow habituel)

Depuis le dossier `installer/` :

```powershell
.\release.ps1 -Version 0.3.0 -Notes "Correction du bug de facture + nouveau filtre historique"
```

Le script fait tout :
1. `flutter build windows --release --dart-define=APP_VERSION=0.3.0`
2. `makensis skyblue.nsi` → `skyblue-setup-0.3.0.exe`
3. Calcule le SHA-256 du `.exe`
4. Génère `manifest.json` avec toutes les infos

À la fin, il affiche les 2 fichiers à uploader :
- `skyblue-setup-0.3.0.exe` (~35 Mo)
- `manifest.json` (~200 octets)

**Upload sur Supabase** :
1. Storage → bucket `releases`
2. Glisse-dépose les 2 fichiers (écrase `manifest.json` si présent)
3. C'est fini.

**Pamela** : au prochain démarrage de son app (ou dans 6h max si l'app est
déjà ouverte), elle voit la bannière "Nouvelle version 0.3.0 disponible".
Un clic → mise à jour automatique.

### Options avancées

Mise à jour bloquante (ex : bug critique de sécurité) :
```powershell
.\release.ps1 -Version 0.3.1 -Notes "Correctif sécurité important" -Mandatory
```

Pamela verra un dialog bloquant "Mise à jour requise pour continuer" au
lieu de la bannière discrète — elle ne pourra pas fermer sans installer.

## Premier install chez Pamela (une seule fois)

1. Publie la version 0.1.0 avec `release.ps1`
2. Télécharge `skyblue-setup-0.1.0.exe` depuis Supabase
3. Transfère à Pamela (WhatsApp, clé USB, ou lien direct)
4. Elle double-clique le `.exe`
5. Windows affiche "SmartScreen : éditeur inconnu" → **"Plus d'infos" → "Exécuter quand même"**
   *(Disparaîtra quand on signera l'installeur — pas urgent.)*
6. Wizard NSIS s'ouvre en français, elle clique 3× "Suivant / Installer / Terminer"
7. L'app démarre.

**Toutes les futures mises à jour** se font depuis l'app elle-même (Phase B, à câbler après).

## Fonctionnement de l'update à distance (Phase B — à venir)

Quand la Phase B sera câblée dans l'app :

```
App v0.2 ouverte chez Pamela
    ↓ toutes les 6h + au boot
Fetch manifest.json depuis Supabase
    ↓
version_remote (0.3.0) > version_local (0.2.0)  ?
    ↓ oui
Bannière discrète en haut : "Nouvelle version 0.3 disponible — [Installer]"
    ↓ Pamela clique
Download skyblue-setup-0.3.0.exe → verify SHA-256 (contre manifest.sha256)
    ↓
Lance l'installeur (silencieux ou visible selon config)
    ↓
App se ferme, installeur remplace les fichiers, app redémarre
```

**Sécurité** :
- HTTPS obligatoire (bucket Supabase)
- Hash SHA-256 vérifié avant install → détecte fichier corrompu / MITM
- L'installeur NE TOUCHE JAMAIS aux données (`Documents\BlueSky\blue_sky.db`)

## Ce qu'il faut savoir

### Où les données de Pamela sont stockées

- **Code de l'app** : `%LOCALAPPDATA%\Skyblue\` (remplacé à chaque update)
- **Données** : `%USERPROFILE%\Documents\BlueSky\blue_sky.db` (**jamais touchées** par l'installeur)

### Rollback (retour arrière) si tu foires une release

1. Sur Supabase, remplace `manifest.json` par la version précédente (ex : recopie l'ancien manifest 0.2.0).
2. Pamela, au prochain check, ne verra plus de bannière (0.2.0 = sa version actuelle).
3. Si elle avait DÉJÀ installé la mauvaise version : prépare un `skyblue-setup-0.4.0.exe` qui est en fait le code de 0.2.0 → elle l'installe pareil comme n'importe quelle update.

### Rétention des vieilles versions

Le bucket `releases` va accumuler des `.exe` (~35 Mo chacun). Rien de grave
à cette échelle — un ménage manuel tous les 6 mois suffit (garde les 3-5
dernières versions au cas où).

### Signature de l'installeur (plus tard)

L'installeur non signé déclenche le warning SmartScreen "éditeur inconnu"
au premier lancement (Pamela clique "Exécuter quand même", puis Windows
retient sa décision). Pour supprimer complètement ce warning :
- Certificat code-signing EV Sectigo : ~90 €/an
- Configuration `signtool.exe` dans `release.ps1`
- À faire une fois qu'on est bien rodé sur le reste.

## Structure JSON du manifest

Généré automatiquement par `release.ps1` — voici la structure attendue :

```json
{
  "version": "0.3.0",
  "release_date": "2026-08-25",
  "download_url": "https://wdwhfgawuozhkeflgcvs.supabase.co/storage/v1/object/public/releases/skyblue-setup-0.3.0.exe",
  "sha256": "3f7b8a9c...",
  "size_bytes": 34572880,
  "notes": "Corrections mineures + nouveau filtre historique.",
  "mandatory": false,
  "min_version_to_upgrade": null
}
```

Champs clés :
- `version` — semver `MAJOR.MINOR.PATCH`
- `download_url` — URL publique du `.exe` sur Supabase Storage
- `sha256` — hash du `.exe`, vérifié après téléchargement par l'app
- `size_bytes` — utilisé pour la barre de progression
- `notes` — 1-3 lignes affichées dans la bannière
- `mandatory` — si `true`, l'update est bloquante (utilise `-Mandatory`)
- `min_version_to_upgrade` — force une étape intermédiaire (rare, laisse `null`)

## Cles Supabase (obligatoire depuis la v0.4)

Les cles ne sont plus ecrites dans le code source. Avant le premier build :

1. Copier `installer/supabase.env.example` en `installer/supabase.env`.
2. Y coller `SUPABASE_URL` et `SUPABASE_ANON_KEY`
   (Supabase -> Project Settings -> API ; jamais la cle `service_role`).
3. `installer/supabase.env` est ignore par git : les cles ne partent pas
   dans le depot.

`release.ps1` lit ce fichier et ajoute automatiquement les `--dart-define`
au build. Sans ce fichier, le build reussit mais produit une application
**100 % locale** : pas de comptes Supabase, pas de synchro, pas de
sauvegarde cloud. Seuls les comptes de secours (`reception`/0000,
`serveuse`/2000, `admin`/7000) permettent alors de se connecter.
