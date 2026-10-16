# Guide de Test - Espace Locataire

## 🧪 Tests Unitaires

### Exécuter les tests

```bash
# Tous les tests
php bin/phpunit

# Tests spécifiques
php bin/phpunit tests/Repository/FavoriteRepositoryTest.php
php bin/phpunit tests/Repository/PostRepositoryTest.php
php bin/phpunit tests/Controller/TenantControllerTest.php
php bin/phpunit tests/Security/Voter/FavoriteVoterTest.php

# Avec code coverage
php bin/phpunit --coverage-html=var/coverage

# Watch mode (si PHPUnit Watch installé)
phpunit-watch run
```

## 📊 Tests Manuels - Checklist

### 1. Authentification
- [ ] Accès page `/locataire/` sans auth → redirection `/login`
- [ ] Après login avec ROLE_LOCATAIRE → accès dashboard
- [ ] Après login avec ROLE_PROPRIETAIRE → pas d'accès `/locataire/`

### 2. Dashboard
- [ ] GET `/locataire/` → 200 OK
- [ ] Affichage statistiques (candidatures, favoris, avis)
- [ ] Affichage candidatures en attente
- [ ] Affichage 3 derniers favoris

### 3. Recherche & Propriétés
- [ ] GET `/locataire/search` → 200 OK
- [ ] Filtre ville (LIKE) fonctionne
- [ ] Filtre budget (≤) fonctionne
- [ ] Filtre pièces (≥) fonctionne
- [ ] Filtre vérifié fonctionne
- [ ] Affichage résultats en grille
- [ ] GET `/locataire/property/1` → affiche détails propriété
- [ ] Affichage informations propriétaire
- [ ] Affichage 3 derniers avis propriétaire

### 4. Favoris
- [ ] GET `/locataire/favorites` → 200 OK
- [ ] POST `/locataire/favorite/toggle/1` → ajoute favori
- [ ] POST `/locataire/favorite/toggle/1` (2e fois) → retire favori
- [ ] Vérification unique (user + property)
- [ ] Affichage list favoris triés DESC par date

### 5. Candidatures
- [ ] GET `/locataire/applications` → 200 OK
- [ ] POST `/locataire/property/1/apply` → crée candidature
- [ ] Vérification candidature pending existante
- [ ] GET `/locataire/application/1` → détails candidature
- [ ] POST `/locataire/application/1/cancel` → annule candidature
- [ ] Statut passe à `cancelled`

### 6. Avis
- [ ] GET `/locataire/reviews` → 200 OK
- [ ] POST `/locataire/review/create/1` → crée avis
- [ ] Vérification validation rating 1-5
- [ ] Calcul moyenne avis
- [ ] Affichage nombre avis

### 7. Communauté - Posts
- [ ] GET `/locataire/community` → 200 OK
- [ ] POST `/locataire/community/post/create` → crée post
- [ ] Vérification champs requis (title, content)
- [ ] Catégorisation fonctionnelle
- [ ] Recherche par titre fonctionne
- [ ] Filtrage par catégorie fonctionne
- [ ] GET `/locataire/community/post/1` → détails post
- [ ] Incrémentation viewCount à chaque visite
- [ ] Affichage commentaires

### 8. Communauté - Commentaires
- [ ] POST `/locataire/community/comment/1` → crée commentaire
- [ ] Vérification champs requis (content)
- [ ] Affichage commentaire après création
- [ ] Auteur du commentaire affiché

### 9. Communauté - Signalements
- [ ] POST `/locataire/community/report` → crée signalement
- [ ] Choix raison signalement fonctionnel
- [ ] Choix priorité fonctionnel
- [ ] Possible signaler post OU commentaire
- [ ] Vérification contraintes

### 10. Partenaires
- [ ] GET `/locataire/partners` → 200 OK
- [ ] Affichage partenaires STATUS_ACTIVE
- [ ] Affichage catégories
- [ ] POST `/locataire/partner/1/contact` → crée notification

### 11. FAQ
- [ ] GET `/locataire/faq` → 200 OK
- [ ] Affichage accordéon FAQ
- [ ] Lien vers support fonctionnel

### 12. Support
- [ ] GET `/locataire/support` → 200 OK
- [ ] POST `/locataire/support` → envoie message support
- [ ] Validation champs formulaire
- [ ] Affichage horaires support

### 13. Profil
- [ ] GET `/locataire/profile` → 200 OK
- [ ] Affichage infos utilisateur
- [ ] Affichage moyenne avis reçus
- [ ] Affichage nombre avis
- [ ] Statut vérification affiché

## 🔐 Tests Sécurité

### Authorization
- [ ] User ne peut voir que ses propres favoris
- [ ] User ne peut supprimer que ses propres favoris
- [ ] User ne peut éditer/supprimer que ses propres posts
- [ ] User ne peut éditer/supprimer que ses commentaires
- [ ] User ne peut voir que ses propres signalements
- [ ] Admin peut éditer les signalements

### Route Protection
- [ ] Toutes routes `/locataire/*` requièrent ROLE_LOCATAIRE
- [ ] ROLE_PROPRIETAIRE ne peut accéder `/locataire/`
- [ ] ROLE_USER ne peut accéder `/locataire/`
- [ ] Non-authentifiés redirects vers `/login`

### Input Validation
- [ ] Champs vides rejetés
- [ ] Rating 1-5 validé
- [ ] Dates valides requises
- [ ] Titres/contenu minmax respectés

## 📈 Tests Performance

### Queries
```bash
# Vérifier N+1 queries
php bin/console debug:doctrine --entity=Property

# Activer query logging
SYMFONY_DEBUG_MODE=1 php bin/console cache:clear
```

### Load Testing
```bash
# Apache Bench (si installé)
ab -n 100 -c 10 http://localhost:8000/locataire/search

# Wrk (si installé)
wrk -t4 -c100 -d30s http://localhost:8000/locataire/
```

## 🗄️ Fixtures de Test

### Charger fixtures
```bash
php bin/console doctrine:fixtures:load

# Avec env spécifique
php bin/console doctrine:fixtures:load --env=test

# Sans confirmation
php bin/console doctrine:fixtures:load --no-interaction
```

### Données créées
- ✅ Tenant user (tenant@test.com)
- ✅ Owner user (owner@test.com)
- ✅ Property (Douala)
- ✅ Favorite
- ✅ Post
- ✅ PostComment
- ✅ Rental (COMPLETED)
- ✅ Review

## 🧬 Tests Intégration

### API Testing (Postman/Insomnia)

```
1. Login
POST /login
Headers: Content-Type: application/x-www-form-urlencoded
Body: email=tenant@test.com&password=password123

2. Dashboard
GET /locataire/
Headers: Cookie: <session_cookie>

3. Search with filters
GET /locataire/search?ville=Douala&budget=200000&pieces=2

4. Toggle favorite
POST /locataire/favorite/toggle/1
Headers: Cookie: <session_cookie>

5. Create application
POST /locataire/property/1/apply
Body: dateDebut=2026-05-01&dateFin=2026-08-31

6. Create post
POST /locataire/community/post/create
Body: title=Test&content=Content&category=conseils

7. Create comment
POST /locataire/community/comment/1
Body: content=Great post!
```

## 📋 Checklist Coverage

### Entités
- [ ] Favorite: CREATE, READ, DELETE
- [ ] Post: CREATE, READ, UPDATE, DELETE
- [ ] PostComment: CREATE, READ, DELETE
- [ ] CommunityReport: CREATE, READ (admin only)
- [ ] Review: CREATE, READ

### Routes
- [ ] 25+ routes testées
- [ ] 100% endpoints répondent

### Voters
- [ ] FavoriteVoter: VIEW, DELETE ✓
- [ ] ReviewVoter: VIEW, EDIT, DELETE ✓
- [ ] PostVoter: VIEW, EDIT, DELETE ✓
- [ ] PostCommentVoter: VIEW, EDIT, DELETE ✓
- [ ] CommunityReportVoter: VIEW, EDIT ✓

### Templates
- [ ] 13 templates rendus correctement
- [ ] CSS responsive testé (mobile, tablet, desktop)
- [ ] Formulaires soumettent correctement

## 🐛 Debugging

### Logs
```bash
# Voir logs erreurs
tail -f var/log/dev.log

# Debug doctrine queries
php bin/console doctrine:query:sql "SELECT * FROM favorite"

# Debug routes
php bin/console debug:router
```

### Database
```bash
# Vérifier migrations
php bin/console doctrine:migrations:status

# Valider schéma
php bin/console doctrine:schema:validate

# Exporter schéma
php bin/console doctrine:schema:create --dump-sql
```

### Profiler
```
http://localhost:8000/_profiler
```

## ✅ Sign-off Checklist

- [ ] Tous tests unitaires passent
- [ ] Tous tests d'intégration passent
- [ ] Tous endpoints sécurisés
- [ ] Tous formulaires validés
- [ ] Performance acceptable (<500ms)
- [ ] Pas d'erreurs logs
- [ ] N+1 queries résolu
- [ ] CSRF protection actif
- [ ] SQL injection prevention actif
- [ ] XSS prevention actif
- [ ] Templates responsive

## 📞 Troubleshooting

### Erreurs communes

#### 1. `SQLSTATE[HY000] [2002]`
```
# Solution: Vérifier config MySQL
php bin/console dbal:run-sql "SELECT 1"
```

#### 2. `Voter doesn't support class`
```
# Solution: Vérifier voter supports()
php bin/console debug:container App\\Security\\Voter
```

#### 3. CSRF token mismatch
```
# Solution: S'assurer du hash token dans form
{{ csrf_token('intention_key') }}
```

#### 4. Route not found
```
# Solution: Vérifier routing config
php bin/console debug:router | grep locataire
```

---

**Version**: 1.0  
**Date**: 29 Avril 2026  
**Framework**: Symfony 7.2.9
