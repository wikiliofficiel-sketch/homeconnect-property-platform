/**
AUDIT DES ROUTES ET FONCTIONNALITÉS
====================================

Fonctionnalités CRÉÉES mais NON ACCESSIBLES:
============================================

1. PROPRIÉTAIRE:
   ✗ AddPropertyScreen - Écran pour ajouter une propriété (stateful)
   ✗ CreatePropertyScreen - Écran pour créer une propriété (stateful)
   ✗ ContractsScreen - Écran pour gérer les contrats (stateful)
   -> Routes manquantes: /add-property, /create-property, /contracts

2. LOCATAIRE:
   ✗ EvaluationsScreen - Écran d'évaluations (stateful, userId requis)
   -> Route manquante: /evaluations/:userId

3. TOUS:
   ✗ ProfileScreen - Écran profil CRÉÉ ET ROUTÉ (/profile) ✓
   ✗ MessagesScreen - Écran messages non routé
   ✗ ChatScreen - Écran chat non routé depuis dashboard

Écrans À IMPLÉMENTER:
====================

1. PROPRIÉTAIRE - Détail Propriété:
   ✓ PropertyDetailScreen - Voir une propriété en détail
   ✗ Routes manquantes: /property-detail/:id

2. PROPRIÉTAIRE - Edit Propriété:
   ✗ EditPropertyScreen - Éditer une propriété
   ✗ Routes manquantes: /edit-property/:id

3. LOCATAIRE - Détail Bien:
   ✓ BienDetailScreen existe mais aucune route
   ✗ Routes manquantes: /bien-detail/:id

4. RECHERCHE GÉNÉRALE:
   ✓ SearchScreen (search/search_screen.dart) existe
   ✗ Route manquante: /search

5. ABONNEMENT/PAIEMENT:
   ✓ AbonnementScreen existe
   ✓ PaymentScreen existe
   ✗ Routes manquantes: /abonnement, /payment

Routes À AJOUTER DANS main.dart:
================================

'/add-property': (context) => const AddPropertyScreen(),
'/create-property': (context) => const CreatePropertyScreen(),
'/contracts': (context) => const ContractsScreen(),
'/evaluations/:userId': (context) => const EvaluationsScreen(userId: ...),
'/property-detail/:id': (context) => PropertyDetailScreen(propertyId: ...),
'/edit-property/:id': (context) => EditPropertyScreen(propertyId: ...),
'/bien-detail/:id': (context) => BienDetailScreen(bienId: ...),
'/search': (context) => const SearchScreen(),
'/abonnement': (context) => const AbonnementScreen(),
'/payment': (context) => const PaymentScreen(),
'/messages': (context) => const MessagesScreen(),
'/chat/:receiverId': (context) => ChatScreen(...),
'/favoris': (context) => const FavorisScreen(),
'/verification': (context) => const VerificationScreen(),
'/reviews': (context) => const ReviewsScreen(),

Boutons À AJOUTER SUR LES DASHBOARDS:
====================================

PROPRIÉTAIRE DASHBOARD - Onglet "Propriétés":
- FAB "+ Ajouter propriété" -> /add-property ✓
- Card clic -> /property-detail/:id ✗
- Card edit button -> /edit-property/:id ✗

PROPRIÉTAIRE DASHBOARD - Onglet "Contrats":
- Afficher ContractsScreen ✗

LOCATAIRE DASHBOARD - Onglet "Recherche":
- Barre recherche -> /search ✗
- Card clic -> /bien-detail/:id ✗

LOCATAIRE DASHBOARD - Onglet "Avis":
- Button "Voir avis" -> /reviews ✗

TOUS LES DASHBOARDS - AppBar:
- Bell notification -> Affichage notifications ✓
- Avatar -> Menu profil ✓
*/
