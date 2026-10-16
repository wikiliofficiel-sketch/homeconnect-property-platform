# 📋 Espace Propriétaire - Documentation Complète

## Vue d'ensemble

L'espace propriétaire est un module complet permettant aux propriétaires certifiés de gérer leurs biens en location. Tous les accès sont protégés par `#[IsGranted('ROLE_PROPRIETAIRE')]`.

**Route d'accès:** `/proprietary`

---

## 🏠 Architecture

### Entités créées

1. **Application** - Représente une candidature de locataire
   - Statuts: `pending`, `accepted`, `refused`, `cancelled`
   - Lie un locataire à une propriété
   - Horodatage de création et réponse

2. **Visite** - Planification de visites
   - Statuts: `planifiee`, `completee`, `annulee`
   - Liée à une Application
   - Date/heure de début et fin
   - Notes libres

3. **Notification** - Système de traçabilité
   - Types: `property_validated`, `application_received`, `application_accepted`, etc.
   - Marque comme lue/non lue
   - Lien optionnel de redirection
   - Entité liée (property, application, visite)

### Repositories

- `ApplicationRepository`: Requêtes sur candidatures
  - `findByStatut()`: Filtrer par statut
  - `findByProperty()`: Candidatures d'un bien
  - `findByLocataire()`: Candidatures d'un locataire
  - `countPending()`: Compte les candidatures en attente

- `VisiteRepository`: Requêtes sur visites
  - `findByStatut()`: Filtrer par statut
  - `findUpcoming()`: Visites à venir
  - `findByApplicationId()`: Visites d'une candidature

- `NotificationRepository`: Requêtes sur notifications
  - `findByDestinataire()`: Toutes les notifications d'un utilisateur
  - `findUnread()`: Notifications non lues
  - `countUnread()`: Compte les non lues
  - `findByType()`: Filtrer par type

---

## 📱 Routes et Fonctionnalités

### 1. **Tableau de Bord** (`/proprietary/`)
Route: `app_owner_dashboard`

**Affiche:**
- Statistiques clés: biens actifs, candidatures en attente, locations actives
- Status d'abonnement (Gratuit/Premium+)
- Nombre de notifications non lues
- Actions rapides (ajouter bien, voir candidatures, etc.)
- État de l'abonnement Premium+

**Contrôles:**
- Affichage d'alerte KYC si non certifié

---

### 2. **Gestion des Biens** (`/proprietary/properties`)
Route: `app_owner_properties`

**Fonctionnalités:**
- Liste tous les biens du propriétaire
- Affiche statut (draft, pending, active, suspended)
- Cartes affichant: titre, lieu, prix, surface, chambres
- Badges pour meublé/parking

**Actions par bien:**
- ✏️ Modifier
- 🗑️ Supprimer (avec confirmation)

**Route création:** `app_owner_property_new` (`POST /proprietary/properties/new`)
- Crée un bien en statut `pending` (attente modération)
- Crée une notification pour l'utilisateur
- Vérification KYC avant publication

**Route modification:** `app_owner_property_edit` (`POST /proprietary/properties/{id}/edit`)
- Modifie tous les champs sauf le statut
- Mise à jour de `updatedAt`

**Route suppression:** `app_owner_property_delete` (`POST /proprietary/properties/{id}/delete`)
- Suppression du bien et ses candidatures en cascade

---

### 3. **Candidatures** (`/proprietary/applications`)
Route: `app_owner_applications`

**Affichage:**
- Liste toutes les candidatures pour les biens du propriétaire
- Tri par date de création (récentes en premier)
- Badges de statut (pending, accepted, refused, cancelled)

**Détails par candidature:**
- Locataire: nom, email, téléphone
- Bien: adresse, prix, surface
- Période demandée: date début/fin
- Motif de refus (si applicable)

**Actions disponibles (si pending):**
- 👁️ Voir détails
- ✓ Accepter
- ✗ Refuser (avec modal pour motif optionnel)

**Route détail:** `app_owner_application_show` (`GET /proprietary/applications/{id}`)
- Affichage complet de l'application
- Liste des visites planifiées
- Formulaire pour planifier une visite
- Boutons accepter/refuser

**Route acceptation:** `app_owner_application_accept` (`POST /proprietary/applications/{id}/accept`)
- Change statut en `accepted`
- Crée notification pour locataire
- Timestamp de réponse

**Route refus:** `app_owner_application_refuse` (`POST /proprietary/applications/{id}/refuse`)
- Change statut en `refused`
- Stocke le motif
- Crée notification pour locataire

---

### 4. **Planification des Visites** (`/proprietary/visites`)
Route: `app_owner_visites`

**Affichage:**
- Liste toutes les visites planifiées du propriétaire
- Tri par date/heure (prochaines en premier)
- Pour chaque visite: bien, locataire, date, heure, notes

**Route planifier visite:** `app_owner_schedule_visite` (`POST /proprietary/applications/{id}/schedule-visite`)
- Formulaire: date/heure début, date/heure fin, notes
- Crée notification pour locataire
- Attachée à l'Application

---

### 5. **Abonnement** (`/proprietary/subscription`)
Route: `app_owner_subscription`

**Affichage des plans:**
1. **Gratuit**
   - Pas de coût
   - Commission: 5%
   - Pas de mise en avant

2. **Premium+** (25 000 FCFA/mois)
   - Commission réduite: 3% (économie 2%)
   - Mise en avant des annonces
   - Statistiques avancées
   - Support prioritaire

**Route upgrade:** `app_owner_subscription_upgrade` (`POST /proprietary/subscription/upgrade`)
- Crée/met à jour Subscription
- Plan: `premium_plus`, statut: `active`
- Date début: maintenant, expiration: +1 mois

**Détails affichés:**
- Plan actuel
- Statut (Actif/Expiré/Annulé)
- Dates début/expiration
- Calcul des économies réalisées

---

### 6. **Notifications** (`/proprietary/notifications`)
Route: `app_owner_notifications`

**Affichage:**
- Liste toutes les notifications de l'utilisateur
- Tri par date (récentes en premier)
- Distinction visuelle des non lues (fond bleu)
- Badge compteur dans la sidebar

**Types de notifications:**
- `property_submitted`: Bien soumis pour modération
- `property_validated`: Bien validé par admin
- `property_suspended`: Bien suspendu
- `application_received`: Nouvelle candidature
- `application_accepted`: Candidature acceptée
- `application_refused`: Candidature refusée
- `visite_scheduled`: Visite planifiée

**Route marquer comme lu:** `app_owner_notification_read` (`POST /proprietary/notifications/{id}/read`)
- Modifie `lue=true` et timestamp `readAt`
- Appel AJAX
- Réponse JSON: `{success: true}`

---

### 7. **Annuaire Partenaires** (`/proprietary/partners`)
Route: `app_owner_partners`

**Affichage:**
- Grille des partenaires avec statut `active`
- Par partenaire: catégorie, description, contact

**Contact partenaire:** `app_owner_partner_contact` (`POST /proprietary/partners/{id}/contact`)
- Modal avec formulaire: email, message
- Envoie message au partenaire

---

## 🔐 Sécurité

### Voters

1. **PropertyVoter**
   - `edit`: Seulement le propriétaire
   - `delete`: Seulement le propriétaire
   - Les admins peuvent tout faire

2. **NotificationVoter**
   - `view`/`edit`: Seulement le destinataire

### Protection des routes

- Toutes les routes nécessitent `ROLE_PROPRIETAIRE`
- Les données des autres propriétaires sont inaccessibles
- KYC requis pour publier un bien

---

## 📊 Relations de base de données

```
User (proprietaire)
├── Properties (OneToMany)
│   ├── Applications (OneToMany)
│   │   └── Visites (OneToMany)
│   └── Reviews (OneToMany)
└── Notifications (OneToMany)

Application
├── Property (ManyToOne)
└── User (locataire, ManyToOne)
    └── Visites (OneToMany)

Subscription
└── User (OneToOne)
```

---

## 💾 Migrations requises

```bash
# Créer les migrations pour les nouvelles entités
php bin/console make:migration

# Exécuter les migrations
php bin/console doctrine:migrations:migrate
```

---

## 🧪 Testting

### Créer un compte propriétaire test

```php
// Via fixture ou script
$user = new User();
$user->setEmail('proprio@test.com');
$user->setPassword($hasher->hashPassword($user, 'password123'));
$user->setRoles(['ROLE_PROPRIETAIRE']);
$user->setKycStatus('approved'); // Certifié
$user->setPrenom('Jean');
$user->setNom('Dupont');
$em->persist($user);
$em->flush();
```

### URLs à tester

1. `/proprietary/` - Dashboard
2. `/proprietary/properties` - Mes biens
3. `/proprietary/properties/new` - Ajouter bien
4. `/proprietary/applications` - Candidatures
5. `/proprietary/visites` - Visites
6. `/proprietary/subscription` - Abonnement
7. `/proprietary/notifications` - Notifications
8. `/proprietary/partners` - Partenaires

---

## 📝 Checklist d'implémentation

✅ Entités créées (Application, Visite, Notification)
✅ Repositories implémentés
✅ PropertyOwnerController (40+ routes)
✅ 9 templates Twig responsive
✅ Système de notifications traçable
✅ Voters pour sécurité
✅ Protections d'accès (ROLE_PROPRIETAIRE)
✅ Vérification KYC avant publication
✅ Commission 5%/3% par plan
✅ Abonnement Premium+ 25 000 FCFA/mois
✅ Interface sidebar avec navigation
✅ Actions rapides
✅ Gestion candidatures/visites

---

## 🚀 Prochaines étapes

1. **Migrations BD:** `php bin/console make:migration`
2. **Compte test:** Créer utilisateur ROLE_PROPRIETAIRE certifié
3. **Tester dashboard:** Vérifier les KPIs
4. **Tester candidatures:** Ajouter bien → Candidature → Accepter/Refuser
5. **Tester visites:** Planifier visite → Recevoir notification
6. **Tester abonnement:** Upgrade Premium+ → Vérifier 3% commission
7. **Tester notifications:** Vérifier traçabilité des actions

---

## 📋 Points clés

- **KYC obligatoire**: Pas de publication sans KYC approuvé
- **Notifications traçables**: Chaque action génère une notification
- **Commission dynamique**: 5% FREE, 3% PREMIUM+
- **Sécurité accès**: Voters + Routes protégées
- **UI responsive**: Mobile, tablet, desktop
- **Abonnement mensuel**: 25 000 FCFA
