# O’Courant Stock

Interface React/Vite responsive reproduisant les principaux écrans de la vidéo fournie.

## Fonctionnalités
- Inventaire d’articles avec catégories Électricité, Plomberie, Câblage et Autre.
- Recherche et filtres par catégorie.
- Ajout, modification et suppression d’articles.
- Photo facultative (sur téléphone, le sélecteur peut proposer l’appareil photo).
- Quantité, unité, prix unitaire, marge, référence fournisseur et notes.
- Statistiques de quantité et de valeur du stock.
- Sauvegarde locale via `localStorage`.
- Export JSON de l’inventaire.

## Démarrer en local
Prérequis : Node.js 20 ou supérieur.

```bash
npm install
npm run dev
```

Pour vérifier la compilation :

```bash
npm run build
```

## Publier dans GitHub
Copie le contenu de ce dossier dans le dépôt `ocourant-stock`, puis commit/push les fichiers. Ne remplace pas les fichiers existants sans vérifier d’abord s’ils contiennent déjà du travail utile.

## À propos de l’iPhone et de l’IPA
Ce dépôt fournit une application web responsive. Il ne contient pas de certificat de signature Apple et ne produit pas directement une IPA installable. Pour une application iOS native/Capacitor, il faut ajouter la configuration iOS et compiler avec Xcode/macOS ou un service de build iOS compatible. Avec un compte Apple gratuit, les possibilités d’installation personnelle sont limitées et l’installation doit généralement être renouvelée régulièrement. Une publication App Store nécessite un abonnement Apple Developer payant.
