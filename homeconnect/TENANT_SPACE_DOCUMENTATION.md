# Espace Locataire (Tenant Space) - Documentation

## 📋 Vue d'ensemble

L'Espace Locataire est un module complet de Symfony 7.2 permettant aux locataires (ROLE_LOCATAIRE) de:
- Rechercher des propriétés avec filtres avancés
- Gérer leurs favoris
- Soumettre des candidatures à des propriétés
- Consulter et laisser des avis sur les propriétaires
- Participer à la communauté (forum)
- Contacter les partenaires
- Accéder à la FAQ et au support

## 🏗️ Architecture

### Entités (Entities)

#### 1. **Favorite** (`src/Entity/Favorite.php`)
- **Objectif**: Suivre les propriétés favorites des locataires
- **Relations**: 
  - ManyToOne → User (locataire)
  - ManyToOne → Property
  - Unique constraint: (locataire_id, property_id)
- **Champs**: id, locataire, property, addedAt (DateTimeImmutable)

#### 2. **Review** (`src/Entity/Review.php`)
- **Objectif**: Système d'évaluation mutuelle entre propriétaires et locataires
- **Relations**:
  - ManyToOne → Rental
  - ManyToOne → User (author)
  - ManyToOne → User (targetUser)
- **Champs**: id, rental, author, targetUser, type (proprietaire/locataire), rating (1-5), comment, timestamps
- **Constants**: TYPE_PROPRIETAIRE, TYPE_LOCATAIRE

#### 3. **Post** (`src/Entity/Post.php`)
- **Objectif**: Forum communautaire pour discussions
- **Relations**:
  - ManyToOne → User (author)
  - OneToMany → PostComment (cascade delete)
- **Champs**: id, author, title, content, category, viewCount, timestamps
- **Catégories**: conseils, questions, annonces, autres

#### 4. **PostComment** (`src/Entity/PostComment.php`)
- **Objectif**: Commentaires sur les posts
- **Relations**:
  - ManyToOne → Post (cascade delete)
  - ManyToOne → User (author)
- **Champs**: id, post, author, content, timestamps

#### 5. **CommunityReport** (`src/Entity/CommunityReport.php`)
- **Objectif**: Signalement d'abus (posts/commentaires)
- **Relations**:
  - ManyToOne → User (reporter)
  - ManyToOne → Post (nullable)
  - ManyToOne → PostComment (nullable)
- **Champs**: id, reporter, post, comment, reason, description, priority, status, reviewedAt, createdAt
- **Constants**:
  - REASON: SPAM, OFFENSIVE, HARASSMENT, FRAUD, ILLEGAL, OTHER
  - PRIORITY: LOW, MEDIUM, HIGH, CRITICAL
  - STATUS: PENDING, REVIEWED, RESOLVED, DISMISSED

### Repositories

#### FavoriteRepository
```php
findByLocataire(int $locataireId): array
isFavorite(int $locataireId, int $propertyId): bool
countByLocataire(int $locataireId): int
```

#### PostRepository
```php
findLatest(int $limit = 10): array
findByCategory(string $category): array
searchByTitle(string $search): array
findByAuthor(int $authorId): array
findMostViewed(int $limit = 5): array
```

#### PostCommentRepository
```php
findByPost(int $postId): array
findByAuthor(int $authorId): array
countByPost(int $postId): int
```

#### CommunityReportRepository
```php
findByStatus(string $status): array
findByReporter(int $reporterId): array
findByReason(string $reason): array
countByStatus(string $status): int
findPending(): array
findCriticalPending(): array
```

#### ReviewRepository (étendu)
```php
findByTargetUser(int $userId): array
findByAuthor(int $authorId): array
findByRental(int $rentalId): array
calculateAverageRating(int $userId): float
countReviews(int $userId): int
getRatingDistribution(int $userId): array
```

### Contrôleur

#### TenantController (`src/Controller/TenantController.php`)

**Route Protection**:
```php
#[Route('/locataire')]
#[IsGranted('ROLE_LOCATAIRE')]
class TenantController extends AbstractController
```

**Routes implémentées** (25+):

| Méthode | Route | Fonction |
|---------|-------|----------|
| GET | `/` | Dashboard avec statistiques |
| GET | `/search` | Recherche propriétés avancée |
| GET | `/property/{id}` | Détail propriété + favoris |
| GET | `/favorites` | Liste des favoris |
| POST | `/favorite/toggle/{propertyId}` | Toggle favori |
| GET | `/applications` | Mes candidatures |
| GET | `/application/{id}` | Détail candidature |
| POST | `/property/{id}/apply` | Soumettre candidature |
| POST | `/application/{id}/cancel` | Annuler candidature |
| GET | `/reviews` | Mes avis reçus |
| POST | `/review/create/{rentalId}` | Créer avis |
| GET | `/community` | Liste forum |
| GET | `/community/post/{id}` | Détail post |
| POST | `/community/post/create` | Créer post |
| POST | `/community/comment/{postId}` | Commenter post |
| POST | `/community/report` | Signaler contenu |
| GET | `/partners` | Partenaires |
| POST | `/partner/{id}/contact` | Contacter partenaire |
| GET | `/faq` | FAQ |
| GET/POST | `/support` | Support contact |
| GET | `/profile` | Mon profil |

### Security Voters

#### FavoriteVoter
- VIEW: Vérifie que c'est le locataire
- DELETE: Vérifie que c'est le locataire

#### ReviewVoter
- VIEW: Locataire cible ou auteur
- EDIT: Auteur uniquement
- DELETE: Auteur uniquement

#### PostVoter
- VIEW: Tous
- EDIT: Auteur uniquement
- DELETE: Auteur uniquement

#### PostCommentVoter
- VIEW: Tous
- EDIT: Auteur uniquement
- DELETE: Auteur uniquement

#### CommunityReportVoter
- VIEW: Reporter uniquement
- EDIT: Admin uniquement

## 📁 Templates

### Base Layout
- `templates/tenant/base.html.twig` - Layout avec sidebar gradient
  - Header: Nom utilisateur + badge rôle
  - Navigation: 10 liens principaux
  - Main content: Zone pour contenu tenant

### Dashboards & Pages

| Fichier | Description |
|---------|-------------|
| `tenant/dashboard.html.twig` | Dashboard avec statistiques et actions rapides |
| `tenant/search/list.html.twig` | Formulaire recherche + résultats propriétés |
| `tenant/property/show.html.twig` | Détail propriété + formulaire candidature |
| `tenant/favorites/list.html.twig` | Grille favoris avec boutons |
| `tenant/applications/list.html.twig` | Liste candidatures avec statuts |
| `tenant/applications/show.html.twig` | Détail candidature |
| `tenant/reviews/list.html.twig` | Avis reçus avec moyenne |
| `tenant/community/posts/list.html.twig` | Forum posts |
| `tenant/community/posts/show.html.twig` | Post + commentaires |
| `tenant/partners.html.twig` | Grille partenaires |
| `tenant/faq.html.twig` | FAQ accordéon |
| `tenant/support.html.twig` | Formulaire support |
| `tenant/profile.html.twig` | Profil utilisateur |

**Style CSS commun**:
- Gradient sidebar: `linear-gradient(135deg, #667eea 0%, #764ba2 100%)`
- Cartes blanches avec ombres
- Grid responsive: `repeat(auto-fill, minmax(250px, 1fr))`
- Badges statuts colorés

## 🔄 Flux principaux

### 1. Recherche et Favori
```
Dashboard → Recherche → Résultats → Détail → Toggle Favori → Favoris
```

### 2. Candidature
```
Propriété → Remplir dates → Soumettre → Mes Candidatures → Détail
```

### 3. Évaluation
```
Candidature acceptée → Location complète → Créer avis → Mes Avis
```

### 4. Communauté
```
Forum → Voir posts → Créer post → Commenter → Signaler abus
```

## 🚀 Installation & Migration

### 1. Migration de base de données
```bash
php bin/console doctrine:migrations:migrate
```

La migration `Version20260429000000.php` crée:
- Table `favorite`
- Table `post`
- Table `post_comment`
- Table `community_report`
- Ajoute colonne `type` à `review`

### 2. Validation
```bash
php bin/console lint:container
php bin/console doctrine:schema:validate
```

### 3. Fixtures (optionnel)
```bash
php bin/console doctrine:fixtures:load
```

## 🔐 Sécurité

### Authentification
- Session-based via AppCustomAuthenticator
- Rôle requis: ROLE_LOCATAIRE

### Autorisation
- Routes protégées par `#[IsGranted('ROLE_LOCATAIRE')]`
- Voters pour entités (FavoriteVoter, PostVoter, etc.)
- Vérification de propriété: `$this->denyAccessUnlessGranted()`

### Type Safety
Pattern utilisé partout:
```php
/** @var User $user */
$user = $this->getUser();
```

## 📊 Statistiques Clés

| Métrique | Valeur |
|----------|--------|
| Entités créées | 5 (Favorite, Post, PostComment, CommunityReport, Review modifié) |
| Repositories | 5 |
| Contrôleur TenantController | ~600 lignes |
| Routes | 25+ |
| Templates | 13 |
| Security Voters | 5 |
| Champs ORM | 40+ |

## 🎨 Design System

### Couleurs
- Gradient principal: #667eea → #764ba2
- Success (vert): #28a745
- Danger (rouge): #dc3545
- Warning (orange): #ffc107
- Info (bleu): #0066cc

### Composants
- Boutons: `.btn`, `.btn-primary`, `.btn-secondary`, `.btn-danger`
- Badges: `.status-pending`, `.status-accepted`, `.status-refused`
- Cartes: `.card`, `.property-card`, `.post-card`
- Grilles: `grid` avec `repeat(auto-fill, minmax(...))`

## 🧪 Tests Recommandés

### Unitaires
- FavoriteRepository.isFavorite()
- PostRepository.searchByTitle()
- ReviewRepository.calculateAverageRating()

### Intégration
- Authentification ROLE_LOCATAIRE
- Toggle favori (add/remove)
- Soumettre candidature
- Créer post + commenter
- Signaler contenu

### Fonctionnels
- Flux complet recherche → candidature
- Édition profil
- Navigation complète sidebar

## 📝 Notes de développement

### Patterns établis
1. **Entity Type Casting**: Toujours caster `getUser()` à User
2. **DateTime**: Utiliser DateTimeImmutable (pas DateTime)
3. **Cascade Delete**: Sur tous les OneToMany
4. **Unique Constraints**: Pour empêcher doublons (ex: Favorite)
5. **Status Constants**: Définir au niveau classe
6. **Repository Methods**: Retourner array, utiliser QueryBuilder

### Extensions possibles
1. Photo uploads pour propriétés
2. Système de notifications email
3. Système de messaging entre users
4. Vérification par SMS
5. Système de paiement
6. Analytics dashboard
7. Chatbot support

## 📞 Support

Pour problèmes:
1. Vérifier logs: `var/log/`
2. Valider container: `php bin/console lint:container`
3. Vérifier migrations: `php bin/console doctrine:migrations:status`
4. Tester routes: `php bin/console debug:router | grep locataire`

---

**Version**: 1.0  
**Date**: 29 Avril 2026  
**Framework**: Symfony 7.2.9  
**PHP**: 8.x
