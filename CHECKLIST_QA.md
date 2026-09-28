# Checklist QA — Skyblue Guest House

Tests manuels des cas limites à faire avant chaque livraison.
Les tests automatisés (`flutter test`) couvrent déjà : ventes/stock, auth/permissions, migration.
Cette checklist couvre ce que le code ne peut pas vérifier seul : UI, réseau, impression, matériel.

Coche au fur et à mesure. Note tout comportement inattendu.

---

## 1. Connexion & rôles

- [ ] Login avec **admin / bluesky** → arrive sur le Dashboard
- [ ] Mauvais mot de passe → message "Mot de passe incorrect", reste sur login
- [ ] Le dropdown liste bien tous les comptes **sauf** les Super Admins
- [ ] Un compte **désactivé** apparaît grisé et ne peut pas se connecter
- [ ] Clic sur "© Skyblue Guest House — v0.1" → ouvre l'accès Super Admin
- [ ] Se connecter en **Serveur** → sidebar = seulement POS, Catalogue, Chambres
- [ ] Se connecter en **Admin** → tout sauf Paramètres
- [ ] Bouton déconnexion → retour au login, session vidée
- [ ] Changer son mot de passe (Paramètres) puis se reconnecter avec le nouveau

## 2. Point de vente (le plus critique)

- [ ] Ajouter plusieurs articles → le total se met à jour correctement
- [ ] **Double-clic rapide sur "Encaisser"** → une seule vente créée (pas de doublon)
- [ ] Encaisser un panier vide → bouton désactivé (rien ne se passe)
- [ ] Changer d'écran (Historique) puis revenir au POS → **le panier est conservé**
- [ ] Vendre un article suivi jusqu'à **stock 0** → tuile passe "ÉPUISÉ", clic bloqué
- [ ] Tenter d'ajouter au-delà du stock → snackbar "Stock insuffisant"
- [ ] Encaisser → la facture PDF s'ouvre automatiquement
- [ ] Nom du client rempli → apparaît sur la facture ; vide → pas de ligne client
- [ ] Vendre en Restaurant puis Terrasse → l'emplacement est bien distinct dans l'historique
- [ ] Vendre une **chambre** (non suivie) → aucun décompte de stock

## 3. Stock & produits

- [ ] Créer un produit avec photo → apparaît dans Stock ET dans le Catalogue (menu)
- [ ] Créer un produit **sans** photo → icône catégorie (verre/plat/hôtel) affichée
- [ ] Activer "Suivi du stock" → champs quantité/seuil apparaissent
- [ ] Désactiver le suivi → le produit se vend sans décompte
- [ ] Bouton "-" à quantité 0 → désactivé (pas de négatif)
- [ ] Ravitailler +24 → la quantité augmente, snackbar de confirmation
- [ ] Produit sous le seuil → badge "Bas" rouge + apparaît dans les alertes du Dashboard
- [ ] Supprimer un produit → disparaît du menu et du POS
- [ ] Prix avec virgule (`1,50`) ET point (`1.50`) → tous deux acceptés
- [ ] Nom vide ou prix invalide → message d'erreur, pas d'enregistrement

## 4. Chambres

- [ ] Check-in avec nom + date → chambre passe "Occupée"
- [ ] Mettre une date de départ **passée** → bannière rouge "check-out en retard" + badge sidebar
- [ ] Check-out → chambre passe "Nettoyage", le rappel disparaît
- [ ] Supprimer une chambre **occupée** → bloqué avec message
- [ ] Supprimer une chambre **libre** → confirmation puis suppression
- [ ] Serveur : pas de bouton "Nouvelle chambre", pas d'Éditer/Supprimer (juste check-in/out)

## 5. Historique & rapports

- [ ] Cliquer "Détail" sur une vente → panneau latéral avec toutes les lignes
- [ ] Rapport PDF synthétique → 1 page, KPIs + tableau
- [ ] Rapport PDF détaillé → tableau **une seule page** (A4 paysage)
- [ ] Export Excel → 3 onglets (Ventes, Par emplacement, Résumé) avec colonne Client
- [ ] Le logo Skyblue apparaît en filigrane sur toutes les pages PDF
- [ ] Accents et symboles (é, à, ·, —, $) s'affichent correctement dans le PDF
- [ ] Nom de fichier = `type_AAAAMMJJHHmm` (ex. `facture_0005_202608142106.pdf`)

## 6. Cloud (Supabase) — offline-first

- [ ] **WiFi coupé** : l'app démarre et fonctionne normalement (vente, stock, tout)
- [ ] Paramètres → badge "Hors ligne" quand pas de réseau
- [ ] WiFi rebranché → badge "En ligne" (bouton rafraîchir)
- [ ] "Sauvegarder dans le cloud" en ligne → succès
- [ ] "Sauvegarder dans le cloud" hors ligne → message "Aucune connexion", pas de crash
- [ ] Ajouter une photo en ligne → uploadée (URL), s'affiche sur un autre poste après restauration
- [ ] Ajouter une photo hors ligne → gardée en local, s'affiche quand même

## 7. Sauvegarde locale & données

- [ ] Exporter la BDD (fichier .db) → fichier créé au chemin choisi
- [ ] Restaurer une sauvegarde → dialog d'avertissement, puis message "redémarrer"
- [ ] Fermer et rouvrir l'app → toutes les données sont toujours là
- [ ] Supprimer `~/Documents/BlueSky/blue_sky.db` puis relancer → base recréée avec le seed

## 8. Robustesse UI / affichage

- [ ] Redimensionner la fenêtre en petit → pas de débordement jaune/noir
- [ ] Basculer Mode clair / Mode sombre → tous les écrans restent lisibles
- [ ] Écran avec beaucoup de produits (30+) → scroll fluide
- [ ] Historique avec beaucoup de ventes → rapport détaillé tient sur une page (sinon tronqué : à surveiller)
- [ ] Catégorie vide (ex. aucune boisson) → sa section disparaît du catalogue

## 9. Volume / stress (optionnel mais recommandé)

- [ ] Créer 50 ventes de suite → l'app reste fluide
- [ ] Générer un rapport détaillé avec 40+ ventes → vérifier qu'elles tiennent sur la page
- [ ] Ravitailler / vendre en boucle → le stock reste cohérent (pas de valeur aberrante)

---

## Comment lancer les tests automatisés

```bash
flutter test
```

Doit afficher `All tests passed!` (23 tests). À relancer après **chaque** modification du code
avant de livrer une nouvelle version.
