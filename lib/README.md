# BLUE-SKY — Gestion Restaurant-Hôtel (Desktop)

App Flutter desktop qui remplace le fichier `BLUE_SKY_Management.xlsx`.
Ce dépôt contient la **Phase 1, étape 1** : base de données locale + catalogue.

## Stack
- **Flutter Desktop** (Windows / macOS / Linux)
- **Drift** (SQLite type-safe, requêtes réactives) — la base de données
- **Riverpod** — la gestion d'état
- **go_router** — la navigation (branché plus tard)
- **fl_chart** — les graphes du futur dashboard
- **intl** — formatage monnaie/dates

## Installation

Ce dossier `lib/` + `pubspec.yaml` doit vivre dans un vrai projet Flutter
(qui contient les dossiers de plateforme `windows/`, `macos/`, `linux/`).
Le plus simple :

```bash
# 1. Créer un projet Flutter neuf (génère les dossiers de plateforme)
flutter create blue_sky
cd blue_sky

# 2. Remplacer le lib/ et le pubspec.yaml par ceux fournis ici
#    (copie/colle le contenu de ce zip par-dessus)

# 3. Activer le desktop de ton OS (une seule fois sur la machine)
flutter config --enable-windows-desktop   # ou --enable-macos-desktop / --enable-linux-desktop

# 4. Récupérer les dépendances
flutter pub get

# 5. GÉNÉRER le code Drift (crée lib/core/database/database.g.dart)
#    À relancer à chaque fois que tu modifies les tables.
dart run build_runner build --delete-conflicting-outputs

# 6. Lancer !
flutter run -d windows      # ou -d macos / -d linux
```

> Tant que l'étape 5 n'est pas faite, l'IDE affiche une erreur sur
> `part 'database.g.dart';` : c'est normal, ce fichier est généré.

## Architecture (feature-first + couche core)

```
lib/
├── main.dart                  # point d'entrée (ProviderScope)
├── app.dart                   # MaterialApp + thème
├── core/                      # briques transverses
│   ├── database/
│   │   ├── tables.dart        # le schéma (Categories, Articles, Sales, SaleItems)
│   │   ├── database.dart      # la classe AppDatabase + ouverture du fichier
│   │   └── seed.dart          # le catalogue initial (tes 16 articles)
│   ├── providers.dart         # databaseProvider (Riverpod)
│   ├── format.dart            # formatage monnaie
│   └── theme.dart             # thème Material 3
└── features/                  # une fonctionnalité = un dossier
    └── catalog/
        ├── catalog_providers.dart  # requête réactive du catalogue
        └── catalog_screen.dart     # l'écran
```

**Principe** : chaque fonctionnalité (catalog, sales, dashboard...) est isolée
dans son dossier `features/xxx/`. Le `core/` contient ce qui est partagé.

## Décisions clés (le "pourquoi")
- **Prix en centimes (int), jamais en double** : évite les erreurs d'arrondi.
- **Lignes de vente = snapshot** : on recopie nom/prix/catégorie au moment de
  la vente, pour que l'historique reste exact même si tu changes les tarifs.
- **Agrégats calculés, pas stockés** : le dashboard se recalcule depuis les
  ventes (fini le bug "Nombre de ventes = 0" de l'Excel).
- **Catégorie référencée par id** : fini l'incohérence Nourritures/Nourriture.

## Où la base est-elle stockée ?
`Documents/blue_sky/blue_sky.sqlite`. Supprime ce fichier pour repartir de zéro
(le seed se relancera).

## Prochaines étapes (Phase 1)
- [ ] Étape 2 : CRUD catalogue (ajouter / modifier / désactiver un article)
- [ ] Étape 3 : saisie de ventes (le ticket) + calcul du total en direct
- [ ] Étape 4 : dashboard du jour (KPIs calculés)
- [ ] Étape 5 : navigation go_router entre les écrans
Puis Phase 2 (historique + graphes + export Excel) et Phase 3 (réservations hôtel).
