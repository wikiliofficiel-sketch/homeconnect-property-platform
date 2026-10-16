# Configuration Routes - Espace Locataire

## Routes Configuration (config/routes.yaml)

```yaml
# Tenant Space Routes - Automatically imported via TenantController annotations

# Note: Routes are defined in TenantController using #[Route] attributes
# This file documents the complete route structure for reference

tenant_routes:
  resource:
    path: ../src/Controller/TenantController.php
    namespace: App\Controller
  type: attribute

# Or if using traditional routing:
# /locataire
#   GET    /                                    → dashboard()
#   GET    /search                              → search()
#   GET    /property/{id}                       → showProperty()
#   GET    /favorites                           → favorites()
#   POST   /favorite/toggle/{propertyId}        → toggleFavorite()
#   GET    /applications                        → myApplications()
#   GET    /application/{id}                    → showApplication()
#   POST   /property/{id}/apply                 → applyToProperty()
#   POST   /application/{id}/cancel             → cancelApplication()
#   GET    /reviews                             → myReviews()
#   POST   /review/create/{rentalId}            → createReview()
#   GET    /community                           → community()
#   GET    /community/post/{id}                 → showPost()
#   POST   /community/post/create               → createPost()
#   POST   /community/comment/{postId}          → createComment()
#   POST   /community/report                    → reportContent()
#   GET    /partners                            → partners()
#   POST   /partner/{id}/contact                → contactPartner()
#   GET    /faq                                 → faq()
#   GET    /support                             → support()
#   POST   /support                             → support()
#   GET    /profile                             → profile()
```

## Vérifier les routes

```bash
# Lister toutes les routes tenant
php bin/console debug:router | grep locataire

# Afficher détail d'une route
php bin/console debug:router app_tenant_dashboard
php bin/console debug:router app_tenant_search
```

## Exemple d'intégration

### 1. Si routes.yaml utilise attribute dispatcher (Symfony 6+):

**config/routes/attributes.yaml** - Ajouter:
```yaml
controllers:
  resource:
    path: ../../src/Controller/
    namespace: App\Controller
  type: attribute
```

Les routes TenantController seront automatiquement découvertes.

### 2. Si routes.yaml utilise annotation (Symfony 5):

**config/routes.yaml**:
```yaml
app_tenant:
  resource: '../src/Controller/TenantController.php'
  type: annotation
```

### 3. Routes manuelles (si nécessaire):

**config/routes.yaml**:
```yaml
app_tenant_dashboard:
  path: /locataire/
  controller: App\Controller\TenantController::dashboard
  methods: GET

app_tenant_search:
  path: /locataire/search
  controller: App\Controller\TenantController::search
  methods: GET

app_tenant_property_show:
  path: /locataire/property/{id}
  controller: App\Controller\TenantController::showProperty
  methods: GET
  requirements:
    id: '\d+'

# ... etc pour chaque route
```

## Firewall Security (config/packages/security.yaml)

```yaml
security:
  firewalls:
    main:
      lazy: true
      provider: app_user_provider
      # Ensure locale is handled
      # ...

  access_control:
    # Protect tenant routes
    - { path: ^/locataire, roles: ROLE_LOCATAIRE }
    - { path: ^/locataire/search, roles: ROLE_LOCATAIRE }
    # ... autres routes publiques avant les routes protégées
```

## Voters Registration (config/services.yaml)

```yaml
services:
  App\Security\Voter\FavoriteVoter:
    tags:
      - security.voter

  App\Security\Voter\ReviewVoter:
    tags:
      - security.voter

  App\Security\Voter\PostVoter:
    tags:
      - security.voter

  App\Security\Voter\PostCommentVoter:
    tags:
      - security.voter

  App\Security\Voter\CommunityReportVoter:
    tags:
      - security.voter
```

Les voters sont automatiquement enregistrés si tu utilises autowiring (configuration par défaut Symfony).

## Navigation Menu

### Templates - Ajouter au layout principal:

```twig
{# templates/base.html.twig #}
<nav>
    {% if is_granted('ROLE_LOCATAIRE') %}
        <div class="tenant-menu">
            <h4>Espace Locataire</h4>
            <ul>
                <li><a href="{{ path('app_tenant_dashboard') }}">Dashboard</a></li>
                <li><a href="{{ path('app_tenant_search') }}">Rechercher</a></li>
                <li><a href="{{ path('app_tenant_favorites') }}">Favoris</a></li>
                <li><a href="{{ path('app_tenant_applications') }}">Candidatures</a></li>
                <li><a href="{{ path('app_tenant_reviews') }}">Avis</a></li>
                <li><a href="{{ path('app_tenant_community') }}">Communauté</a></li>
                <li><a href="{{ path('app_tenant_partners') }}">Partenaires</a></li>
                <li><a href="{{ path('app_tenant_faq') }}">FAQ</a></li>
                <li><a href="{{ path('app_tenant_support') }}">Support</a></li>
                <li><a href="{{ path('app_tenant_profile') }}">Profil</a></li>
            </ul>
        </div>
    {% endif %}
</nav>
```

## Testing Routes

```bash
# Test authentification
php bin/console make:test App\Controller\TenantController

# Accéder à la route
curl -b cookies.txt http://localhost:8000/locataire/
# → Redirection vers login si non authentifié

# Après login
curl -b cookies.txt http://localhost:8000/locataire/
# → Dashboard page (HTTP 200)
```

## Commands de Debug Utiles

```bash
# Voir toutes les routes
php bin/console debug:router

# Filtrer par prefix
php bin/console debug:router | grep tenant

# Détail d'une route
php bin/console debug:router app_tenant_search

# Générer une URL
php bin/console router:debug app_tenant_property_show -- 1

# Vérifier l'authentification
php bin/console debug:event-dispatcher security

# Lister les voters
php bin/console debug:container | grep -i voter
```

## Endpoints Summary

### Public (Pas protégé si pas ROLE_LOCATAIRE)
- None - Tous les endpoints `/locataire/*` sont protégés

### Protégés ROLE_LOCATAIRE
```
GET  /locataire/                           Dashboard
GET  /locataire/search                     Recherche avancée
GET  /locataire/property/{id}              Détail propriété
GET  /locataire/favorites                  Mes favoris
POST /locataire/favorite/toggle/{propId}   Toggle favori
GET  /locataire/applications               Mes candidatures
GET  /locataire/application/{id}           Détail candidature
POST /locataire/property/{id}/apply        Soumettre candidature
POST /locataire/application/{id}/cancel    Annuler candidature
GET  /locataire/reviews                    Mes avis
POST /locataire/review/create/{rentalId}   Créer avis
GET  /locataire/community                  Forum
GET  /locataire/community/post/{id}        Détail post
POST /locataire/community/post/create      Créer post
POST /locataire/community/comment/{postId} Commenter
POST /locataire/community/report           Signaler
GET  /locataire/partners                   Partenaires
POST /locataire/partner/{id}/contact       Contacter
GET  /locataire/faq                        FAQ
GET  /locataire/support                    Support formulaire
POST /locataire/support                    Soumettre support
GET  /locataire/profile                    Mon profil
```

---

*Generated: 29 Avril 2026*
*Symfony 7.2.9*
