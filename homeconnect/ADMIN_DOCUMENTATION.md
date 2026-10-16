# 📊 Documentation - Tableau de bord Administrateur HomeConnect

## Vue d'ensemble

Le backoffice administrateur de HomeConnect est un système complet de gestion avec **7 onglets principaux** permettant une modération et une administration complètes du site.

---

## 🏗️ Architecture

### Accès et Sécurité
- **Route**: `/admin/`
- **Rôle requis**: `ROLE_ADMIN`
- **Protection**: Vérification des permissions Symfony
- **Layout**: Template `admin/base.html.twig` avec navigation persistante

### Contrôleurs Admin
```
AdminDashboardController       → Tableau de bord principal
AdminUsersController          → Gestion utilisateurs et KYC
AdminPropertiesController     → Modération des biens
AdminReportsController        → Traitement des signalements
AdminSubscriptionsController  → Gestion des abonnements Premium+
AdminCommissionsController    → Suivi des revenus
AdminPartnersController       → Annuaire des partenaires
```

---

## 1️⃣ Tableau de bord (Dashboard)

**Route**: `/admin/`

### Indicateurs affichés
- 📊 Nombre total d'utilisateurs
- 🏠 Biens actifs / en attente
- 📅 Locations (total / en cours)
- 🚩 Signalements ouverts (+ critiques en évidence)
- 💳 Abonnements Premium+ actifs
- 💰 Commissions totales (+ ce mois)

### Actions rapides
- Modérer les biens en attente
- Traiter les signalements critiques
- Vérifier les KYC en suspens

**Template**: `admin/dashboard/index.html.twig`

---

## 2️⃣ Gestion des Utilisateurs

**Routes**:
- `GET /admin/users/` - Liste des utilisateurs
- `GET /admin/users/{id}/detail` - Détail utilisateur
- `POST /admin/users/{id}/toggle-verify` - Vérifier/révoquer
- `POST /admin/users/{id}/add-role` - Ajouter un rôle
- `POST /admin/users/{id}/delete` - Supprimer

### Filtres disponibles
- Par rôle (Propriétaire, Locataire, Admin)
- Par statut de vérification

### Informations affichées
- Email, nom, téléphone, ville
- Rôles actuels
- Statut de vérification

### 🆔 Système KYC (Know Your Customer)

**Statuts KYC**:
- ⏳ `pending` - Soumis, en attente d'approbation
- ✅ `approved` - Approuvé, peut publier
- ❌ `rejected` - Rejeté, raison visible

**Champs KYC** (sur User):
- `kyc_status` - Statut actuel
- `kyc_documents` - JSON array des documents
- `kyc_submitted_at` - Date de soumission
- `kyc_approved_at` - Date d'approbation
- `kyc_rejection_reason` - Raison du rejet
- `num_siret` - SIRET pour professionnels

**Actions administrateur**:
```php
// Approuver un KYC
$user->setKycStatus('approved');
$user->setKycApprovedAt(new DateTimeImmutable());

// Rejeter
$user->setKycStatus('rejected');
$user->setKycRejectionReason('Documents insuffisants');
```

**Vérification des permissions**:
```php
// Un propriétaire ne peut publier que s'il est KYC approuvé
if ($user->canPublishProperty()) {
    // Permettre la publication
}
```

**Templates**: 
- `admin/users/index.html.twig` - Liste avec filtres
- `admin/users/show.html.twig` - Détail et KYC

---

## 3️⃣ Modération des Biens

**Routes**:
- `GET /admin/properties/` - Liste avec filtres
- `GET /admin/properties/{id}/detail` - Détail bien
- `POST /admin/properties/{id}/approve` - Approuver
- `POST /admin/properties/{id}/suspend` - Suspendre
- `POST /admin/properties/{id}/delete` - Supprimer

### Statuts de biens
- 📝 `draft` - Brouillon
- ⏳ `pending` - En attente de modération
- ✅ `active` - Actif et visible
- 🔒 `suspended` - Suspendu (avec motif)

### Informations affichées
- Titre, description, localisation
- Propriétaire
- Tarif, surface, chambres
- Signalements associés
- Date de création

### Actions
- Approuver (passer en active)
- Suspendre (avec motif obligatoire)
- Supprimer

**Templates**:
- `admin/properties/index.html.twig` - Liste par statut
- `admin/properties/show.html.twig` - Détail et actions

---

## 4️⃣ Gestion des Signalements

**Routes**:
- `GET /admin/reports/` - Liste avec filtres
- `GET /admin/reports/{id}/detail` - Détail signalement
- `POST /admin/reports/{id}/resolve` - Résoudre
- `POST /admin/reports/{id}/dismiss` - Rejeter

### Types de signalements
- 🏠 Bien
- 👤 Utilisateur  
- 💬 Avis

### Niveaux de priorité
- 🟢 `low` - Basse
- 🟡 `medium` - Moyenne (défaut)
- 🟠 `high` - Élevée
- 🔴 `critical` - Critique (alerte admin)

### Statuts de résolution
- 🔴 `open` - Ouvert, non traité
- 🟡 `in_review` - En révision
- ✅ `resolved` - Résolu avec sanction
- ❌ `dismissed` - Rejeté/non fondé

### Sanctions possibles
- ⚠️ `warning` - Avertissement (message utilisateur)
- 🔒 `suspension` - Suspension temporaire
- 🚫 `ban` - Bannissement (suppression des rôles)

### Workflow de traitement
```
1. Signalement créé par utilisateur
   ↓
2. Admin filtre par priorité/type
   ↓
3. Admin examine les preuves
   ↓
4. Admin applique sanction
   ↓
5. Notification utilisateur (optionnel)
   ↓
6. Suivi de l'impact
```

**Templates**:
- `admin/reports/index.html.twig` - Liste avec priorités
- `admin/reports/show.html.twig` - Détail et résolution

---

## 5️⃣ Gestion des Abonnements

**Routes**:
- `GET /admin/subscriptions/` - Liste avec filtres
- `GET /admin/subscriptions/{id}/detail` - Détail
- `POST /admin/subscriptions/{id}/renew` - Prolonger
- `POST /admin/subscriptions/{id}/upgrade` - Upgrader

### Plans disponibles
- 📊 `free` - Gratuit (défaut)
- ⭐ `premium_plus` - Premium+ (5% de commission → 3%)

### Statuts
- ✅ `active` - Actif et valide
- ⏳ `expired` - Expiré
- ❌ `cancelled` - Annulé

### Modèle de données (Subscription)
```php
class Subscription {
    - proprietaire: User (OneToOne)
    - plan: string (free | premium_plus)
    - dateDebut: DateTimeImmutable
    - dateExpiration: DateTimeImmutable
    - statut: string
}
```

### Actions administrateur
```php
// Prolonger un abonnement de 3 mois
$subscription->setDateExpiration(
    $subscription->getDateExpiration()->modify('+3 months')
);

// Upgrader en Premium+
$subscription->setPlan('premium_plus');
$subscription->setDateDebut(new DateTimeImmutable());
$subscription->setDateExpiration(
    (new DateTimeImmutable())->modify('+1 month')
);
```

### Indicateurs
- Nombre de Premium+ actifs
- Abonnements expirant dans 7 jours

**Templates**:
- `admin/subscriptions/index.html.twig` - Liste avec expirations
- `admin/subscriptions/show.html.twig` - Détail et actions

---

## 6️⃣ Suivi des Commissions

**Route**: `GET /admin/commissions/`

### Modèle Commission
```php
class Commission {
    - rental: Rental (ManyToOne)
    - montantLocation: float
    - pourcentageCommission: float (5% | 3%)
    - montantCommission: float (auto-calculée)
    - createdAt: DateTimeImmutable
}
```

### Calcul des commissions
```
Commission = montantLocation × (pourcentageCommission / 100)

Propriétaire standard (Free):     5%
Propriétaire Premium+:            3%
```

### Statistiques affichées
- 💰 Total commissions (all-time)
- 💰 Ce mois
- 💰 Cette année

### Tableau détaillé
- Bien concerné
- Montant location
- Pourcentage appliqué
- Commission générée
- Propriétaire
- Date

**Créé automatiquement**: Quand une location passe en `completed`

**Template**: `admin/commissions/index.html.twig`

---

## 7️⃣ Annuaire des Partenaires

**Routes**:
- `GET /admin/partners/` - Liste
- `GET /admin/partners/new` - Formulaire ajout
- `POST /admin/partners` - Créer
- `GET /admin/partners/{id}/detail` - Détail
- `GET /admin/partners/{id}/edit` - Formulaire édition
- `POST /admin/partners/{id}` - Mettre à jour
- `POST /admin/partners/{id}/toggle-status` - Activer/Désactiver
- `POST /admin/partners/{id}/delete` - Supprimer

### Champs Partner
```php
class Partner {
    - nom: string
    - categorie: string
    - description: string
    - website: string (nullable)
    - telephone: string (nullable)
    - email: string (nullable)
    - adresse: string
    - personne_contact: string
    - statut: string (active | inactive | suspended)
    - createdAt: DateTimeImmutable
    - updatedAt: DateTimeImmutable
}
```

### Statuts
- ✅ `active` - Visible dans l'annuaire
- ⏸️ `inactive` - Masqué temporairement
- 🔒 `suspended` - Suspendu (violation)

### Actions
- Ajouter nouveau partenaire
- Modifier détails
- Activer/Désactiver
- Supprimer

**Templates**:
- `admin/partners/index.html.twig` - Grille de partenaires
- `admin/partners/new.html.twig` - Formulaire création
- `admin/partners/edit.html.twig` - Formulaire édition
- `admin/partners/show.html.twig` - Détail

---

## 🔐 Entités et Relations

### User (étendu)
```
User
├── id (PK)
├── email (unique)
├── password (hashed)
├── prenom, nom
├── telephone, ville
├── roles: array
├── isVerified: bool
├── kyc_status, kyc_documents, kyc_approved_at, kyc_rejection_reason
├── properties: OneToMany
└── rentals: OneToMany
```

### Property
```
Property
├── id (PK)
├── proprietaire: User (ManyToOne)
├── titre, description
├── adresse, codePostal, ville
├── prix, surface, nbChambres
├── statut (draft|pending|active|suspended|deleted)
├── motifSuspension
├── createdAt, updatedAt
├── rentals: OneToMany
├── reviews: OneToMany
└── reports: OneToMany
```

### Rental
```
Rental
├── id (PK)
├── property: Property (ManyToOne)
├── locataire: User (ManyToOne)
├── dateDebut, dateFin
├── prixTotal
├── statut (pending|confirmed|ongoing|completed|cancelled)
├── createdAt
└── reviews: OneToMany
```

### Report
```
Report
├── id (PK)
├── type (property|user|review)
├── property: Property (nullable)
├── utilisateur: User (nullable)
├── review: Review (nullable)
├── signataire: User (ManyToOne) - celui qui signale
├── motif
├── priorite (low|medium|high|critical)
├── statut (open|in_review|resolved|dismissed)
├── sanction (warning|suspension|ban)
├── noteAdmin
├── createdAt
└── resolvedAt
```

### Subscription
```
Subscription
├── id (PK)
├── proprietaire: User (OneToOne)
├── plan (free|premium_plus)
├── dateDebut, dateExpiration
├── statut (active|expired|cancelled)
├── createdAt, updatedAt
```

### Commission
```
Commission
├── id (PK)
├── rental: Rental (ManyToOne)
├── montantLocation
├── pourcentageCommission (5|3)
├── montantCommission (auto-calculé)
└── createdAt
```

### Partner
```
Partner
├── id (PK)
├── nom, categorie
├── description, website
├── telephone, email
├── adresse, personne_contact
├── statut (active|inactive|suspended)
├── createdAt, updatedAt
```

---

## 🎯 Workflows clés

### 1. KYC Propriétaire
```
Propriétaire envoie documents
         ↓
Admin examine (onglet Utilisateurs)
         ↓
Admin approuve/rejette
         ↓
Propriétaire reçoit notification
         ↓
Si approuvé → peut publier des biens
```

### 2. Modération Bien
```
Propriétaire publie bien
         ↓
Bien passe en "pending" 
         ↓
Admin modère (onglet Biens)
         ↓
Admin approuve ou suspend
         ↓
Si approuvé → visible pour locataires
```

### 3. Traitement Signalement
```
Utilisateur signale bien/user/avis
         ↓
Signalement créé avec priorité
         ↓
Admin filtre par priorité
         ↓
Admin examine et applique sanction
         ↓
Utilisateur ciblé notifié + sanctions appliquées
         ↓
Suivi dans Commission/Ban records
```

### 4. Gestion Premium+
```
Admin voit Premium+ expirant bientôt
         ↓
Admin prolonge ou upgrade manuellement
         ↓
Propriétaire garde ses fonctionnalités
         ↓
Commission réduite (5% → 3%)
```

---

## 📋 Checklist d'utilisation

### ✅ Premier accès
- [ ] Créer compte administrateur
- [ ] Attribuer rôle `ROLE_ADMIN`
- [ ] Ajouter partenaires initiaux
- [ ] Configurer tarifs de commission

### ✅ Modération quotidienne
- [ ] Approuver biens en attente
- [ ] Traiter signalements critiques
- [ ] Vérifier KYC propriétaires
- [ ] Consulter dashboard pour alertes

### ✅ Gestion hebdomadaire
- [ ] Renouveler abonnements expirant
- [ ] Consulter commissions
- [ ] Vérifier bannissements actifs
- [ ] Mettre à jour annuaire partenaires

### ✅ Rapports mensuels
- [ ] Analyse commissions mensuelles
- [ ] Audit utilisateurs et biens
- [ ] Rapport signalements/sanctions
- [ ] Performance Premium+

---

## 🔧 Configuration et Déploiement

### Variables d'environnement
```env
# Authentification
DATABASE_URL=postgresql://user:password@localhost/homeconnect
MAILER_URL=smtp://...

# Admin
ADMIN_EMAIL=admin@homeconnect.fr
```

### Commandes Doctrine
```bash
# Créer les migrations
bin/console make:migration

# Exécuter les migrations
bin/console doctrine:migrations:migrate

# Charger les fixtures (si disponibles)
bin/console doctrine:fixtures:load
```

### Permissions Symfony
```yaml
# config/packages/security.yaml
access_control:
    - { path: ^/admin, roles: ROLE_ADMIN }
```

---

## 📞 Support et Maintenance

### Logs d'administration
- Localisés dans `var/log/`
- Traces de chaque action d'admin
- Utiles pour audit et dépannage

### Bonne pratique
✅ Toujours motiver les suspensions/bannissements
✅ Archiver les rapports importants
✅ Vérifier KYC avant publication massive
✅ Surveiller les signalements critiques

---

**Dernière mise à jour**: 29 avril 2026
