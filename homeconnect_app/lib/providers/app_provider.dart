import 'package:flutter/material.dart';
import '../models/user.dart';      // ← IMPORT AJOUTÉ
import '../models/property.dart';  // ← IMPORT AJOUTÉ
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  User? _user;  // ← UserModel → User
  bool _isLoading = false;
  String _error = '';
  List<Property> _properties = [];  // ← PropertyModel → Property
  final List<Property> _favorites = [];
  bool _isDarkMode = false;
  Locale _locale = const Locale('fr');
  List<Map<String, dynamic>> _messages = [];
  bool _isInitialized = false;

  AppProvider() {
    initSession();
  }

  Future<void> initSession() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final email = prefs.getString('email');
      
      if (token != null && email != null) {
        ApiService.setToken(token);
        // Reconstruire l'user depuis SharedPreferences (IDs serveur)
        final userId   = prefs.getInt('user_id') ?? 0;
        final role     = prefs.getString('user_role') ?? 'locataire';
        final nom      = prefs.getString('user_nom') ?? '';
        final prenom   = prefs.getString('user_prenom') ?? '';
        if (userId > 0) {
          _user = User(
            id: userId,
            email: email,
            nom: nom,
            prenom: prenom,
            role: role,
          );
          await _loadProperties();
          debugPrint('✅ Session restaurée pour : $email (id=$userId)');
        }
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur lors de la restauration de session: $e');
    }
  }

  final Map<String, Map<String, String>> _translations = {
    'fr': {
      'welcome': 'Bienvenue sur HomeConnect',
      'login': 'Connexion',
      'register': 'Inscription',
      'profile': 'Profil Utilisateur',
      'settings': 'Paramètres',
      'logout': 'Déconnexion',
      'dark_mode': 'Mode Sombre',
      'language': 'Langue',
      'admin_panel': 'Panneau Admin',
      'owner_space': 'Espace Propriétaire',
      'search_placeholder': 'Rechercher un bien...',
      'no_notifications': 'Aucune notification',
      'dashboard': 'Tableau de bord',
      'users': 'Utilisateurs',
      'properties': 'Biens',
      'reports': 'Signalements',
      'subscriptions': 'Abonnements',
      'commissions': 'Commissions',
      'logs': 'Journaux',
      'config': 'Configuration',
      'overview': 'Aperçu',
      'my_properties': 'Mes biens',
      'applications': 'Candidatures',
      'complaints': 'Plaintes',
      'contracts': 'Contrats',
      'premium': 'Premium',
      'add_property': 'Ajouter un bien',
      'edit_profile': 'Modifier le profil',
      'change_password': 'Changer le mot de passe',
      'certification': 'Ma Certification KYC',
      'notifications': 'Notifications',
      'cancel': 'Annuler',
      'confirm': 'Confirmer',
      'save': 'Enregistrer',
      'delete': 'Supprimer',
      'active': 'Actif',
      'pending': 'En attente',
      'suspended': 'Suspendu',
      'favorites': 'Favoris',
      'evaluations': 'Évaluations',
      'community': 'Communauté',
      'help': 'Aide',
      'payments': 'Paiements',
      'complaints_and_reports': 'Plaintes & Signalements',
      'report_issue_desc': 'Signalez un problème avec un bien, un propriétaire ou un service.',
      'file_complaint': 'Déposer une plainte',
      'my_complaints': 'Mes plaintes',
      'report_type': 'Type de signalement',
      'complaint_title': 'Titre de la plainte',
      'complaint_description': 'Description détaillée',
      'complaint_sent_success': 'Votre plainte a été enregistrée avec succès.',
      'no_complaints_yet': 'Vous n\'avez déposé aucune plainte.',
      'how_to_apply': 'Comment postuler ?',
      'how_to_apply_desc': 'Parcourez les annonces, sélectionnez un bien et cliquez sur "Postuler".',
      'manage_apps': 'Gérer mes candidatures',
      'manage_apps_desc': 'Suivez l\'état de vos demandes dans l\'onglet "Candidatures".',
      'problem_support': 'Un problème ? Contactez-nous',
      'problem_support_desc': 'Notre équipe est là pour vous aider 24h/24.',
      'contact_whatsapp': 'Contactez-nous sur WhatsApp',
      'contact_support_desc': 'Réponse rapide pour vos questions urgentes.',
      'chat_on_whatsapp': 'Discuter sur WhatsApp',
      'support_whatsapp_number': '+22990000000',
      'open_support_ticket': 'Ouvrir un ticket support',
      'contact_support': 'Contacter le support',
      'contact_support_instruction': 'Décrivez votre problème et nous vous répondrons par email.',
      'describe_problem_hint': 'Tapez votre message ici...',
      'send': 'Envoyer',
      'message_sent_success': 'Message envoyé avec succès.',
      'message_sent_error': 'Erreur lors de l\'envoi du message.',
      'recommended_for_you': 'Recommandés pour vous',
      'see_all': 'Voir tout',
      'hello': 'Bonjour',
      'find_your_home': 'Trouvez votre logement idéal',
      'verified': 'Vérifié',
      'tenant_space': 'Espace Locataire',
      'find_future_home': 'Trouvez votre futur chez-vous',
      'contact_admin': 'Contacter l\'Admin',
      'messaging': 'Messagerie',
      'recommended_properties': 'Biens recommandés',
      'visits': 'Visites',
      'confidence': 'Confiance',
      'no_properties': 'Aucun bien disponible',
      'search': 'Recherche',
      'total_properties': 'Biens totaux',
      'active_properties': 'Biens actifs',
      'total_views': 'Vues totales',
      'trust_rating': 'Ma note de confiance',
      'subscription_status': 'Statut d\'abonnement',
      'free_plan': 'Plan gratuit',
      'certified_account': 'Compte Certifié',
      'certification_required': 'Certification Requise',
      'identity_verified_desc': 'Votre identité a été vérifiée. Vous avez un accès complet.',
      'identity_not_verified_desc': 'Veuillez ajouter vos dossiers (pièce d\'identité, etc.) pour publier des biens.',
      'see_kyc_folder': 'Voir mon dossier KYC',
      'add_kyc_folder': 'Ajouter mes dossiers KYC',
      'upgrade_premium': 'Passer à Premium+',
      'renew': 'Renouveler',
      'subscribe': 'S\'abonner',
      'reject': 'Refuser',
      'approve': 'Approuver',
      'approved': 'Approuvées',
      'rejected': 'Refusées',
      'contract_management': 'Gestion des contrats',
      'generate_contract': 'Générer un contrat',
      'create_pdf_contract': 'Créer un PDF de contrat',
      'inventory': 'État des lieux',
      'inventory_desc': 'Documenter l\'état des locaux',
      'active_contracts': 'Contrats actifs',
      'select_property_contract': 'Sélectionnez une propriété pour générer un contrat PDF.',
      'generate': 'Générer',
      'close': 'Fermer',
      'inactive': 'Inactif',
      'days_remaining': 'jours restants',
      'basic_features_access': 'Accès à des fonctionnalités de base',
      'premium_advantages': 'Avantages Premium+',
      'unlimited_highlight': 'Mise en avant illimitée',
      'highlight_visibility_desc': 'Augmentez la visibilité de vos biens',
      'advanced_stats': 'Statistiques avancées',
      'advanced_stats_desc': 'Analyse détaillée des vues et candidatures',
      'reduced_commission': 'Commission réduite',
      'commission_desc': 'De 5% à 3% sur vos transactions',
      'priority_support': 'Support prioritaire',
      'priority_support_desc': 'Assistance 24/7 dédiée',
      'renew_subscription': 'Renouveler l\'abonnement',
      'renew_one_month_desc': 'Renouveler pour 1 mois supplémentaire?',
      'partner_services': 'Services Partenaires',
      'access_verified_services': 'Accédez à des services vérifiés',
      'moving_transport': 'Déménagement & transport',
      'secure_moving_desc': 'Services de déménagement sécurisés',
      'secure_payments': 'Paiements sécurisés',
      'rent_management_desc': 'Gestion des loyers',
      'legal_services': 'Services juridiques',
      'legal_advice_desc': 'Conseil et documentation légale',
      'handyman_platform': 'Plateforme artisanale',
      'small_works_desc': 'Petits travaux et dépannage',
      'admin_subtitle': 'Gestion complète de la plateforme',
      'loading_data': 'Chargement des données...',
      'kyc_management': 'Gestion KYC',
      'support': 'Support',
      'logout_confirmation': 'Déconnexion',
      'logout_confirmation_desc': 'Voulez-vous vraiment vous déconnecter ?',
      'online': 'En ligne',
      'recent_activities': 'Activités récentes',
      'no_activity_yet': 'Aucune activité pour le moment',
      'activities_will_appear_here': 'Les activités apparaîtront ici au fur et à mesure',
      'revenue_analysis': 'Analyse des Revenus',
      'platform_immo_benin': 'Plateforme Immo Bénin',
      'admin_dashboard': 'Tableau de bord Admin',
      'new_user': 'Nouvel utilisateur',
      'new_property': 'Nouveau bien',
      'add_user': 'Ajouter un utilisateur',
      'last_name': 'Nom',
      'first_name': 'Prénom',
      'email': 'Email',
      'password': 'Mot de passe',
      'phone': 'Téléphone',
      'tenant': 'Locataire',
      'landlord': 'Propriétaire',
      'admin': 'Administrateur',
      'fill_all_fields': 'Veuillez remplir tous les champs obligatoires',
      'email_already_used': 'Cet email est déjà utilisé',
      'added_successfully': 'ajouté avec succès',
      'add': 'Ajouter',
      'edit': 'Modifier',
      'email_address': 'Adresse Email',
      'email_label': 'Adresse Email',
      'password_label': 'Mot de passe',
      'yes': 'Oui',
      'no': 'Non',
      'months': 'mois',
      'immediate': 'Immédiate',
      'error_loading': 'Erreur lors du chargement',
      'retry': 'Réessayer',
      'no_description': 'Aucune description disponible.',
      'no_equipment': 'Aucun équipement spécifié',
      'technical_sheet': 'Fiche Technique',
      'total_rooms': 'Pièces totales',
      'verified_by_app': 'Bien vérifié par HomeConnect',
      'certified_app': 'Certifié HomeConnect',
      'not_certified': 'Non certifié',
      'apply_for_property': 'Postuler pour ce bien',
      'im_interested': 'Je suis intéressé (Contact Admin)',
      'comments_title': 'Commentaires',
      'login_title': 'Se connecter',
      'login_subtitle': 'L\'immobilier premium à portée de main',
      'required_kyc_docs': 'Documents KYC Requis',
      'owner_certification_desc': 'Pour publier des biens, votre profil doit être certifié.',
      'id_document': 'Pièce d\'identité (CNI/Passeport)',
      'address_proof': 'Justificatif de domicile',
      'property_title': 'Titre de propriété',
      'attach': 'Joindre',
      'my_information': 'Mes Informations',
      'display_preferences': 'Préférences d\'affichage',
      'logout_homeconnect_desc': 'Souhaitez-vous vraiment quitter votre session HomeConnect ?',
      'quit': 'Quitter',
      'loading_profile': 'Chargement du profil...',
      'checking_status': 'Vérification du statut...',
      'your_info': 'Vos informations',
      'full_name': 'Nom complet',
      'supporting_docs': 'Documents justificatifs',
      'kyc_docs_instruction': 'Veuillez fournir des photos claires de vos documents originaux pour accélérer le processus de validation.',
      'identity_card': 'Pièce d\'identité',
      'id_card_subtitle': 'CNI, Passeport ou Permis',
      'address_proof_subtitle': 'Facture EDF, Eau ou Contrat',
      'property_title_subtitle': 'Preuve de possession du bien',
      'processing_dossier': 'Dossier en cours de traitement',
      'admins_verifying': 'Nos administrateurs vérifient vos documents.',
      'submit_dossier': 'Soumettre mon dossier',
      'kyc_certification': 'Certification KYC',
      'congratulations': 'Félicitations !',
      'identity_verified_success': 'Votre identité a été vérifiée avec succès par nos services.',
      'file_selected': 'Fichier sélectionné',
      'exclusive_advantages': 'Avantages exclusifs',
      'certified_badge_benefit': 'Badge "Certifié" visible partout',
      'priority_highlight_benefit': 'Mise en avant prioritaire de vos annonces',
      'secure_payment_access_benefit': 'Accès aux fonctionnalités de paiement sécurisé',
      'community_trust_benefit': 'Confiance renforcée auprès de la communauté',
      'under_review': 'En cours d\'examen',
      'docs_rejected': 'Documents Rejetés',
      'current_status': 'Statut actuel',
      'submit_dossier_confirm': 'Soumettre le dossier ?',
      'dossier_analysis_desc': 'Vos documents seront analysés par notre équipe sous 24 à 48 heures. Vous recevrez une notification dès validation.',
      'dossier_sent_success': 'Dossier envoyé avec succès !',
      'identity_missing': 'Pièce d\'identité manquante',
      'forgot_password': 'Mot de passe oublié ?',
      'new_to_app': 'Nouveau sur HomeConnect ?',
      'create_account': 'Créer un compte',
      'reset_title': 'Réinitialisation',
      'reset_body': 'Entrez votre adresse email pour recevoir un code de récupération.',
      'send_code': 'Envoyer le code',
      'email_required': 'Email requis',
      'email_invalid': 'Email invalide',
      'password_required': 'Mot de passe requis',
      'register_title': 'Inscription',
      'phone_label': 'Téléphone',
      'confirm_password': 'Confirmer',
      'accept_terms': 'J\'accepte les conditions d\'utilisation et la politique de confidentialité',
      'create_account_btn': 'Créer mon compte',
      'already_registered': 'Déjà inscrit ? Se connecter',
      'required_field': 'Requis',
      'min_char': 'Min 6 caractères',
      'passwords_match': 'Incohérent',
      'accept_terms_error': 'Vous devez accepter les conditions',
      'register_success': 'Inscription réussie ! Connectez-vous pour continuer',
      'optional': 'optionnel',
      'average_rating': 'Note moyenne',
      'total_evaluations': 'évaluations reçues',
      'evaluations_received': 'Évaluations reçues',
      'evaluations_given': 'Évaluations données',
      'rate_owner': 'Évaluer un propriétaire',
      'choose_rental': 'Choisir la location concernée',
      'select_rating': 'Sélectionner une note',
      'add_comment_opt': 'Ajouter un commentaire (optionnel)',
      'submit_evaluation': 'Valider l\'évaluation',
      'no_evaluations': 'Aucune évaluation reçue pour le moment',
      'confidence_badge': 'Badge de confiance',
      'evaluate_now': 'Évaluer maintenant',
      'pay_rent': 'Payer le loyer',
      'pay_service': 'Payer un service',
      'transaction_history': 'Historique des transactions',
      'mobile_money': 'Mobile Money',
      'credit_card': 'Carte Bancaire',
      'bank_transfer': 'Virement Bancaire',
      'payment_simulated': 'Paiement simulé – transaction enregistrée',
      'transaction_ref': 'Référence',
      'transaction_date': 'Date & Heure',
      'amount': 'Montant',
      'status': 'Statut',
      'type': 'Type',
      'select_payment_method': 'Choisir le moyen de paiement',
      'confirm_payment': 'Confirmer le paiement',
      'all': 'Tout',
      'rent': 'Loyer',
      'service': 'Service',
      'refunded': 'Remboursé',
      'general_info': 'Informations générales',
      'localisation': 'Localisation',
      'price_fees': 'Prix & frais',
      'detailed_features': 'Caractéristiques détaillées',
      'equipment': 'Équipements',
      'media': 'Médias',
      'rules_conditions': 'Règles & conditions',
      'property_desc': 'Description détaillée',
      'property_type': 'Type de bien',
      'property_status': 'Statut',
      'rooms': 'Nombre de pièces',
      'area': 'Superficie',
      'address': 'Adresse complète',
      'city': 'Ville',
      'postal_code': 'Code postal',
      'gps_coords': 'Coordonnées GPS',
      'monthly_rent': 'Prix mensuel (location)',
      'sale_price': 'Prix de vente',
      'charges_incl': 'Charges comprises ?',
      'charges_amount': 'Montant des charges',
      'deposit': 'Dépôt de garantie',
      'agency_fees': 'Frais d’agence',
      'bedrooms': 'Nombre de chambres',
      'living_rooms': 'Nombre de salons',
      'bathrooms': 'Nombre de salles de bain',
      'toilets': 'Nombre de toilettes',
      'kitchen_type': 'Type de cuisine',
      'floor': 'Étage du bien',
      'elevator': 'Ascenseur',
      'parking': 'Parking',
      'garden_terrace': 'Jardin / Terrasse',
      'balcony': 'Balcon',
      'pets_allowed': 'Animaux acceptés',
      'smokers_allowed': 'Fumeurs acceptés',
      'min_lease': 'Durée minimale de location',
      'notice_period': 'Préavis',
      'availability': 'Disponibilité',
    },
    'en': {
      'welcome': 'Welcome to HomeConnect',
      'login': 'Login',
      'register': 'Register',
      'profile': 'User Profile',
      'settings': 'Settings',
      'logout': 'Logout',
      'dark_mode': 'Dark Mode',
      'language': 'Language',
      'admin_panel': 'Admin Panel',
      'owner_space': 'Owner Space',
      'search_placeholder': 'Search property...',
      'no_notifications': 'No notifications',
      'dashboard': 'Dashboard',
      'users': 'Users',
      'properties': 'Properties',
      'reports': 'Reports',
      'subscriptions': 'Subscriptions',
      'commissions': 'Commissions',
      'logs': 'Logs',
      'config': 'Config',
      'overview': 'Overview',
      'my_properties': 'My properties',
      'applications': 'Applications',
      'complaints': 'Complaints',
      'contracts': 'Contracts',
      'premium': 'Premium',
      'add_property': 'Add property',
      'edit_profile': 'Edit profile',
      'change_password': 'Change password',
      'certification': 'My KYC Certification',
      'notifications': 'Notifications',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'save': 'Save',
      'delete': 'Delete',
      'active': 'Active',
      'pending': 'Pending',
      'suspended': 'Suspended',
      'favorites': 'Favorites',
      'evaluations': 'Reviews',
      'community': 'Community',
      'help': 'Help',
      'payments': 'Payments',
      'recommended_for_you': 'Recommended for you',
      'see_all': 'See all',
      'hello': 'Hello',
      'find_your_home': 'Find your ideal home',
      'verified': 'Verified',
      'tenant_space': 'Tenant Space',
      'find_future_home': 'Find your future home',
      'contact_admin': 'Contact Admin',
      'messaging': 'Messaging',
      'recommended_properties': 'Recommended properties',
      'visits': 'Visits',
      'confidence': 'Confidence',
      'no_properties': 'No properties available',
      'total_properties': 'Total Properties',
      'active_properties': 'Active Properties',
      'total_views': 'Total Views',
      'certified_account': 'Certified Account',
      'certification_required': 'Certification Required',
      'identity_verified_desc': 'Your identity has been verified. You have full access.',
      'identity_not_verified_desc': 'Please add your documents (ID, etc.) to publish properties.',
      'see_kyc_folder': 'See my KYC folder',
      'add_kyc_folder': 'Add my KYC folders',
      'upgrade_premium': 'Upgrade to Premium+',
      'renew': 'Renew',
      'subscribe': 'Subscribe',
      'reject': 'Reject',
      'approve': 'Approve',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'contract_management': 'Contract Management',
      'generate_contract': 'Generate Contract',
      'create_pdf_contract': 'Create a PDF contract',
      'inventory': 'Inventory',
      'inventory_desc': 'Document the state of the premises',
      'active_contracts': 'Active Contracts',
      'select_property_contract': 'Select a property to generate a PDF contract.',
      'generate': 'Generate',
      'close': 'Close',
      'free_plan': 'Free Plan',
      'inactive': 'Inactive',
      'days_remaining': 'days remaining',
      'basic_features_access': 'Access to basic features',
      'premium_advantages': 'Premium+ Advantages',
      'unlimited_highlight': 'Unlimited Highlight',
      'highlight_visibility_desc': 'Increase the visibility of your properties',
      'advanced_stats': 'Advanced Statistics',
      'advanced_stats_desc': 'Detailed analysis of views and applications',
      'reduced_commission': 'Reduced Commission',
      'commission_desc': 'From 5% to 3% on your transactions',
      'priority_support': 'Priority Support',
      'priority_support_desc': 'Dedicated 24/7 assistance',
      'renew_subscription': 'Renew Subscription',
      'renew_one_month_desc': 'Renew for 1 additional month?',
      'partner_services': 'Partner Services',
      'access_verified_services': 'Access verified services',
      'moving_transport': 'Moving & Transport',
      'secure_moving_desc': 'Secure moving services',
      'secure_payments': 'Secure Payments',
      'rent_management_desc': 'Rent management',
      'legal_services': 'Legal Services',
      'legal_advice_desc': 'Advice and legal documentation',
      'handyman_platform': 'Handyman Platform',
      'small_works_desc': 'Small works and troubleshooting',
      'admin_subtitle': 'Complete platform management',
      'loading_data': 'Loading data...',
      'kyc_management': 'KYC Management',
      'support': 'Support',
      'logout_confirmation': 'Logout',
      'logout_confirmation_desc': 'Do you really want to log out?',
      'online': 'Online',
      'recent_activities': 'Recent activities',
      'no_activity_yet': 'No activity for the moment',
      'activities_will_appear_here': 'Activities will appear here gradually',
      'revenue_analysis': 'Revenue Analysis',
      'platform_immo_benin': 'Immo Benin Platform',
      'admin_dashboard': 'Admin Dashboard',
      'new_user': 'New user',
      'new_property': 'New property',
      'add_user': 'Add a user',
      'last_name': 'Last Name',
      'first_name': 'First Name',
      'email': 'Email',
      'password': 'Password',
      'phone': 'Phone',
      'tenant': 'Tenant',
      'landlord': 'Landlord',
      'admin': 'Administrator',
      'fill_all_fields': 'Please fill all mandatory fields',
      'email_already_used': 'This email is already used',
      'added_successfully': 'added successfully',
      'add': 'Add',
      'email_address': 'Email Address',
      'required_kyc_docs': 'Required KYC Documents',
      'owner_certification_desc': 'To publish properties, your profile must be certified.',
      'id_document': 'Identity Document (ID/Passport)',
      'address_proof': 'Proof of Address',
      'property_title': 'Property Title',
      'attach': 'Attach',
      'my_information': 'My Information',
      'display_preferences': 'Display Preferences',
      'logout_homeconnect_desc': 'Do you really want to leave your HomeConnect session?',
      'quit': 'Quit',
      'loading_profile': 'Loading profile...',
      'checking_status': 'Checking status...',
      'your_info': 'Your information',
      'full_name': 'Full name',
      'supporting_docs': 'Supporting documents',
      'kyc_docs_instruction': 'Please provide clear photos of your original documents to speed up the validation process.',
      'identity_card': 'Identity card',
      'id_card_subtitle': 'ID Card, Passport or Driver\'s License',
      'address_proof_subtitle': 'Utility Bill or Contract',
      'property_title_subtitle': 'Proof of property ownership',
      'processing_dossier': 'Dossier being processed',
      'admins_verifying': 'Our administrators are verifying your documents.',
      'submit_dossier': 'Submit my dossier',
      'kyc_certification': 'KYC Certification',
      'congratulations': 'Congratulations!',
      'identity_verified_success': 'Your identity has been successfully verified by our services.',
      'file_selected': 'File selected',
      'exclusive_advantages': 'Exclusive advantages',
      'certified_badge_benefit': '"Certified" badge visible everywhere',
      'priority_highlight_benefit': 'Priority highlighting of your ads',
      'secure_payment_access_benefit': 'Access to secure payment features',
      'community_trust_benefit': 'Enhanced trust with the community',
      'under_review': 'Under review',
      'docs_rejected': 'Documents Rejected',
      'current_status': 'Current status',
      'submit_dossier_confirm': 'Submit the dossier?',
      'dossier_analysis_desc': 'Your documents will be analyzed by our team within 24 to 48 hours. You will receive a notification upon validation.',
      'dossier_sent_success': 'Dossier sent successfully!',
      'identity_missing': 'Missing identity document',
      'contact_whatsapp': 'Contact via WhatsApp',
      'contact_support_desc': 'Need help? Our advisors are available on WhatsApp to assist you.',
      'support_whatsapp_number': '+22990000000',
      'how_to_apply': 'How to apply for an ad?',
      'how_to_apply_desc': 'Go to the Search tab, select a property and click Apply.',
      'manage_apps': 'How to manage my applications?',
      'manage_apps_desc': 'The Applications tab allows you to track the status of your applications and schedule visits.',
      'problem_support': 'What to do in case of a problem?',
      'problem_support_desc': 'Use the reporting system on the property page or contact our WhatsApp support.',
      'chat_on_whatsapp': 'Chat on WhatsApp',
      'contact_support': 'Contact Support',
      'contact_support_instruction': 'Describe your problem or question in detail.',
      'describe_problem_hint': 'Your message...',
      'open_support_ticket': 'Open a support ticket',
      'message_sent_success': 'Message sent successfully!',
      'message_sent_error': 'Error sending message.',
      'add_property_btn': 'Add a Property',
      'no_properties_published': 'No properties published\nCreate your first property',
      'email_label': 'Email Address',
      'password_label': 'Password',
      'forgot_password': 'Forgot password?',
      'new_to_app': 'New to HomeConnect?',
      'create_account': 'Create an account',
      'reset_title': 'Reset Password',
      'reset_body': 'Enter your email address to receive a recovery code.',
      'send_code': 'Send Code',
      'email_required': 'Email required',
      'email_invalid': 'Invalid email',
      'password_required': 'Password required',
      'register_title': 'Registration',
      'phone_label': 'Phone Number',
      'confirm_password': 'Confirm',
      'accept_terms': 'I accept the terms of use and privacy policy',
      'create_account_btn': 'Create my account',
      'already_registered': 'Already registered? Login',
      'required_field': 'Required',
      'min_char': 'Min 6 characters',
      'passwords_match': 'Passwords don\'t match',
      'owner': 'Owner',
      'accept_terms_error': 'You must accept the terms',
      'register_success': 'Registration successful! Login to continue',
      'optional': 'optional',
      'average_rating': 'Average Rating',
      'total_evaluations': 'evaluations received',
      'evaluations_received': 'Evaluations Received',
      'evaluations_given': 'Evaluations Given',
      'rate_owner': 'Rate a Landlord',
      'choose_rental': 'Choose the rental',
      'select_rating': 'Select a rating',
      'add_comment_opt': 'Add a comment (optional)',
      'submit_evaluation': 'Submit evaluation',
      'no_evaluations': 'No evaluations received yet',
      'confidence_badge': 'Confidence Badge',
      'evaluate_now': 'Evaluate now',
      'pay_rent': 'Pay Rent',
      'pay_service': 'Pay a Service',
      'transaction_history': 'Transaction History',
      'mobile_money': 'Mobile Money',
      'credit_card': 'Credit Card',
      'bank_transfer': 'Bank Transfer',
      'payment_simulated': 'Payment simulated – transaction recorded',
      'transaction_ref': 'Reference',
      'transaction_date': 'Date & Time',
      'amount': 'Amount',
      'status': 'Status',
      'type': 'Type',
      'select_payment_method': 'Select payment method',
      'confirm_payment': 'Confirm Payment',
      'all': 'All',
      'rent': 'Rent',
      'service': 'Service',
      'confirmed': 'Confirmed',
      'failed': 'Failed',
      'refunded': 'Refunded',
      'general_info': 'General Information',
      'localisation': 'Location',
      'price_fees': 'Price & Fees',
      'detailed_features': 'Detailed Features',
      'equipment': 'Equipment',
      'media': 'Media',
      'rules_conditions': 'Rules & Conditions',
      'property_desc': 'Detailed Description',
      'property_type': 'Property Type',
      'property_status': 'Status',
      'rooms': 'Number of Rooms',
      'area': 'Area (sqm)',
      'address': 'Full Address',
      'city': 'City',
      'postal_code': 'Postal Code',
      'gps_coords': 'GPS Coordinates',
      'monthly_rent': 'Monthly Rent',
      'sale_price': 'Sale Price',
      'charges_incl': 'Charges Included?',
      'charges_amount': 'Charges Amount',
      'deposit': 'Security Deposit',
      'agency_fees': 'Agency Fees',
      'bedrooms': 'Bedrooms',
      'living_rooms': 'Living Rooms',
      'bathrooms': 'Bathrooms',
      'toilets': 'Toilets',
      'kitchen_type': 'Kitchen Type',
      'floor': 'Floor Level',
      'elevator': 'Elevator',
      'parking': 'Parking',
      'garden_terrace': 'Garden / Terrace',
      'balcony': 'Balcony',
      'pets_allowed': 'Pets Allowed',
      'smokers_allowed': 'Smokers Allowed',
      'min_lease': 'Minimum Lease Duration',
      'notice_period': 'Notice Period',
      'availability': 'Availability',
      'certified_app': 'Certified by HomeConnect',
      'not_certified': 'Not certified',
      'apply_for_property': 'Apply for this property',
      'im_interested': 'I\'m interested (Contact Admin)',
      'yes': 'Yes',
      'no': 'No',
      'months': 'months',
      'immediate': 'Immediate',
      'error_loading': 'Error while loading',
      'retry': 'Retry',
      'no_description': 'No description available.',
      'no_equipment': 'No equipment specified',
      'technical_sheet': 'Technical Sheet',
      'total_rooms': 'Total Rooms',
      'verified_by_app': 'Verified by HomeConnect',
      'comments_title': 'Comments',
      'login_title': 'Welcome to HomeConnect',
      'login_subtitle': 'Find your ideal property',
      'edit': 'Edit',
    },
    'fon': {
      'welcome': 'Koude HomeConnect ji',
      'login': 'So me do je',
      'register': 'So nyi kon d e me',
      'profile': 'Medesuno kpikpa',
      'settings': 'Linlin le',
      'logout': 'Ton sin me',
      'dark_mode': 'Zingindo',
      'language': 'Gbe',
      'admin_panel': 'Gan sin kpo',
      'owner_space': 'Xweto sin tenme',
      'yes': 'Ɛɛ',
      'no': 'Ao',
      'months': 'Sun le',
      'immediate': 'Dìn dìn',
      'login_title': 'So me do je',
      'login_subtitle': 'Xwé ɖagbe le ɖò alɔ towe mɛ',
      'search_placeholder': 'Ba xo de...',
      'no_notifications': 'Wen de de a',
      'dashboard': 'Xwetene',
      'users': 'Mɛ le',
      'properties': 'Xwé le',
      'reports': 'Wɛn le',
      'subscriptions': 'Yɛkan le',
      'commissions': 'Akue le',
      'logs': 'Wlanwlan le',
      'config': 'Vɔ mɛ línlín',
      'overview': 'Kpikpa',
      'my_properties': 'Xwé nyeto le',
      'applications': 'Wéma biba le',
      'complaints': 'Hùnhùn le',
      'contracts': 'Wéma gbé dídó',
      'premium': 'Premium',
      'add_property': 'Gɔ xwé na',
      'edit_profile': 'Línlín kpɔ d\'a wu',
      'change_password': 'Sɔ gàn tɛ d\'ayǐ',
      'certification': 'KYC kpikpa',
      'notifications': 'Wen gbe',
      'cancel': 'Gbéyí',
      'confirm': 'Gbé ɖíɖó',
      'save': 'Sɛ xwé d\'ayǐ',
      'delete': 'Súnsún',
      'active': 'É ɖò zɔn',
      'suspended': 'Kpò te',
      'favorites': 'Nǔ e nɔ hɛn',
      'evaluations': 'Kpɔ́ndéwú',
      'community': 'Kplé',
      'help': 'Alɔdómɛ',
      'recommended_for_you': 'E mɛɖé sɔ́ ɖ\'áyǐ nú we',
      'see_all': 'Kpɔ́n bǐ',
      'hello': 'Kúdóo',
      'find_your_home': 'Mɔ tɛnmɛ e jɛ we é',
      'verified': 'É nyɔ́ bǐ',
      'tenant_space': 'Fí e locataire lɛ nɔ nɔ é',
      'find_future_home': 'Mɔ xwé towe sɔgbe',
      'contact_admin': 'Kplé xá admin',
      'messaging': 'Wɛn sɛ́dó',
      'recommended_properties': 'Xwé ɖagbe le',
      'visits': 'Kpikpon',
      'confidence': 'Jiɖiɖe',
      'no_properties': 'Xwé ɖé ɖě à',
      'total_properties': 'Xwé lɛ bǐ',
      'active_properties': 'Xwé e ɖò zɔn lɛ é',
      'total_views': 'Mɛ nabi e kpɔ́n é',
      'certified_account': 'Akɔ́ntá e è ɖyí é',
      'certification_required': 'Certification hudo wɛ',
      'identity_verified_desc': 'È ɖyí we bǐ. A sixú wà nǔ bǐ.',
      'identity_not_verified_desc': 'Sɔ́ wéma towe lɛ d\'áyǐ bá mɔ tɛnmɛ.',
      'see_kyc_folder': 'Kpɔ́n wéma ce lɛ',
      'add_kyc_folder': 'Sɔ́ wéma ce lɛ d\'áyǐ',
      'upgrade_premium': 'Yi Premium+ jí',
      'renew': 'Vɔ́ sɔ́ d\'áyǐ',
      'subscribe': 'Sɔ́ nyìkɔ d\'áyǐ',
      'reject': 'Gbɛ́',
      'approve': 'Yí gbe',
      'approved': 'É nyɔ́',
      'rejected': 'É nyɔ́ ǎ',
      'contract_management': 'Wéma kplé',
      'generate_contract': 'Bló wéma',
      'create_pdf_contract': 'Bló PDF wéma',
      'inventory': 'Xwé mɛ kpikpon',
      'inventory_desc': 'Wlǎn nǔ e ɖò xwé mɛ lɛ é',
      'active_contracts': 'Wéma e ɖò zɔn lɛ é',
      'select_property_contract': 'Sɔ́ xwé ɖokpó bá bló wéma.',
      'generate': 'Bló',
      'close': 'Sú',
      'free_plan': 'Plan vɔ̌tɔ́',
      'inactive': 'É ɖò zɔn ǎ',
      'days_remaining': 'azǎn e kpò lɛ é',
      'basic_features_access': 'Nǔ tàjí lɛ kpowun',
      'premium_advantages': 'Premium+ nyɔ́na lɛ',
      'unlimited_highlight': 'Mɛ bǐ na mɔ we',
      'highlight_visibility_desc': 'Na xwé towe lɛ hɛn nyɔ́',
      'advanced_stats': 'Nǔ nabi e è wà é',
      'advanced_stats_desc': 'Kpɔ́n mɛ nabi e wá é',
      'reduced_commission': 'Axɔ́ e è nɔ sǔ é hwe',
      'commission_desc': 'Sín 5% yi 3% jí',
      'priority_support': 'Alɔdó tàjí',
      'priority_support_desc': 'Assistance 24/7',
      'renew_subscription': 'Vɔ́ sɔ́ nyìkɔ d\'áyǐ',
      'renew_one_month_desc': 'Vɔ́ sɔ́ d\'áyǐ nú sùn ɖokpó dǒ jí?',
      'partner_services': 'Azɔ̌watɔ́ lɛ',
      'access_verified_services': 'Mɔ azɔ̌ e è ɖyí lɛ é',
      'moving_transport': 'Sinsɛnzɔ́',
      'secure_moving_desc': 'Sinsɛnzɔ́ ɖagbe',
      'secure_payments': 'Axɔ́ súsú ɖagbe',
      'rent_management_desc': 'Axɔ́ xwé tɔn',
      'legal_services': 'Sɛ́n kplé',
      'legal_advice_desc': 'Sɛ́n sín alɔdó',
      'handyman_platform': 'Azɔ̌watɔ́ kplé',
      'small_works_desc': 'Azɔ̌ kpɛví kpɛví lɛ',
      'admin_subtitle': 'Plateforme bǐ sín kpikpon',
      'loading_data': 'Nǔ lɛ sɔ́ ɖ\'áyǐ wɛ...',
      'kyc_management': 'Wéma lɛ kplé',
      'support': 'Alɔdó',
      'logout_confirmation': 'Gbéyí',
      'logout_confirmation_desc': 'A jló na gbéyí à?',
      'online': 'É ɖò zɔn',
      'recent_activities': 'Nǔ e è wà dìn lɛ é',
      'no_activity_yet': 'Nǔ ɖé sɔ́ ɖ\'áyǐ dìn ǎ',
      'activities_will_appear_here': 'Nǔ lɛ na wá wá dìn dìn',
      'revenue_analysis': 'Akɔkwɛ kpɔ́n',
      'platform_immo_benin': 'Immo Benin Plateforme',
      'admin_dashboard': 'Admin sín kplé',
      'new_user': 'Mɛ yɔyɔ́',
      'new_property': 'Xwé yɔyɔ́',
      'add_user': 'Gɔ mɛ ɖokpó na',
      'email': 'Email',
      'password': 'Sɔ gàn tɛ',
      'phone': 'Alokan',
      'tenant': 'Locataire',
      'landlord': 'Propriétaire',
      'admin': 'Administrateur',
      'fill_all_fields': 'Wlǎn nǔ lɛ bǐ',
      'email_already_used': 'Email elɔ ko ɖò zɔn',
      'added_successfully': 'é nyɔ́ d\'áyǐ',
      'add': 'Gɔ na',
      'email_label': 'Email línlín',
      'password_label': 'Sɔ gàn tɛ',
      'required_kyc_docs': 'KYC wéma lɛ bǐ',
      'owner_certification_desc': 'Bá dó xwé towe lɛ hɔn ɔ, a ɖó na sɔ́ wéma towe lɛ d\'áyǐ.',
      'id_document': 'ID/Passeport',
      'address_proof': 'Xwé sín wéma',
      'attach': 'Sɔ́ d\'áyǐ',
      'my_information': 'Nǔ ce lɛ',
      'display_preferences': 'Kpɔ́n nǔ e a jló é',
      'logout_homeconnect_desc': 'A jló na gbéyí ɖò HomeConnect à?',
      "quit": "Gbéyí",
      "loading_profile": "Profil towe sɔ́ ɖ'áyǐ wɛ...",
      "checking_status": "Kpɔ́n tɛnmɛ towe...",
      "your_info": "Nǔ towe lɛ",
      "full_name": "Nyìkɔ bǐ",
      "supporting_docs": "Wéma lɛ",
      "kyc_docs_instruction": "Sɔ́ wéma towe lɛ sín fɔtóo ɖagbe dó bló blɔbló.",
      "identity_card": "Wéma e è ɖyí we é",
      "id_card_subtitle": "ID, Passeport aló Permis",
      "address_proof_subtitle": "Xwé sín wéma aló Contrat",
      "property_title_subtitle": "Xwé sín nyìkɔ wéma",
      "processing_dossier": "Wéma lɛ ɖò kpikpon wɛ",
      "admins_verifying": "Azɔ̌watɔ́ lɛ ɖò wéma towe lɛ kpɔ́n wɛ.",
      "submit_dossier": "Sɛ́ wéma lɛ dó",
      "kyc_certification": "KYC kpikpa",
      "congratulations": "É nyɔ́ ɖagbe!",
      'forgot_password': 'Gàn wɔn à?',
      'new_to_app': 'A wá HomeConnect yɔyɔ wɛ à?',
      'create_account': 'Sɔ nyi kon',
      'reset_title': 'Vɔ bló gàn',
      'reset_body': 'Wlan email línlín to we na mɔ gàn yɔyɔ.',
      'send_code': 'Sɛ wɛn ɖó',
      'email_required': 'Email hudo wɛ',
      'email_invalid': 'Email nyi ɖagbe à',
      'password_required': 'Gàn hudo wɛ',
      'register_title': 'Sɔ nyi kon',
      'first_name': 'Nyi',
      'last_name': 'Xota',
      'phone_label': 'Alokan línlín',
      'confirm_password': 'Vɔ bló',
      'accept_terms': 'Un yí gbe na wéma línlín le',
      'create_account_btn': 'Sɔ nyi kon',
      'already_registered': 'A ko sɔ nyi kon à? Byɔ mɛ',
      'required_field': 'Hudo wɛ',
      'min_char': 'Gàn nabi 6 hudo',
      'passwords_match': 'Gàn le nyí ɖokpo à',
      'owner': 'Propriétaire',
      'accept_terms_error': 'A ɖo na yí gbe na wéma línlín le',
      'register_success': 'A sɔ nyi kon ɖagbe! Byɔ mɛ lo',
      'optional': 'nǔ é jló mɛ ɔ',
      'average_rating': 'Xó ɖagbe kpo nyi kpo',
      'total_evaluations': 'mɛ é ɖɔ xó le',
      'evaluations_received': 'Xó ɖagbe é a yí le',
      'evaluations_given': 'Xó ɖagbe é a ɖɔ le',
      'rate_owner': 'Kpɔn mɛ é nɔ hɛn xɔ ɔ',
      'choose_rental': 'Sɔ xɔ é a hɛn ɔ',
      'select_rating': 'Sɔ akwo é a na na ɔ',
      'add_comment_opt': 'Vɔ ɖɔ xó ɖé (nú é jló mɛ)',
      'submit_evaluation': "Sɔ xó ɔ sɔ ɖ'ayǐ",
      'no_evaluations': 'Mɛ ɖé kún ko ɖɔ xó ɖé nú we ó',
      'confidence_badge': "Ji ɖé d'ewu",
      'evaluate_now': 'Kpɔn mɛ ɔ din',
      'payments': 'Akwo súsú',
      'pay_rent': 'Sú xɔkwé',
      'pay_service': 'Sú azɔ ɖé',
      'transaction_history': 'Fi é akwo zun hɛn gbɔ le',
      'mobile_money': 'Mobile Money',
      'credit_card': 'Cáti',
      'bank_transfer': 'Bánki sín vɔsɔsɔ',
      'payment_simulated': "Súsú ɔ ko nyi mɔ – e ko sɔ ɖ'ayǐ",
      'transaction_ref': 'Kɛ́n',
      'transaction_date': 'Azan kpo ganmɛ kpo',
      'amount': 'Akwo nabi',
      'status': 'Ninɔmɛ',
      'type': 'Hɛnnu',
      'select_payment_method': 'Sɔ ali é a na sú akwo ɔ gbɔ',
      'confirm_payment': "Sɔ súsú ɔ ɖ'ayǐ",
      'all': 'Bǐ',
      'rent': 'Xɔkwé',
      'service': 'Azɔ',
      'pending': 'É ɖo te',
      'confirmed': 'É ko sɔ',
      'failed': 'É hwayi',
      'refunded': 'É ko lɛ kɔ',
      'general_info': 'Xó jɛ nukɔn le',
      'localisation': 'Fi é ɖée',
      'price_fees': 'Akwo kpodo hudo le',
      'detailed_features': 'Xwé línlín xó le',
      'equipment': 'Nǔ ɖo xwé mɛ le',
      'media': 'Fɔtóo kpodo vǐdyò le',
      'rules_conditions': 'Sɛ́n kpodo nǔ é ɖo na bló le',
      'property_title': 'Xwé nyikɔ',
      'property_desc': 'Xwé xó bǐ',
      'property_type': 'Xwé alɔkpa',
      'property_status': 'Fi é ɖée é dìn',
      'rooms': 'Xwé xá nabi',
      'area': 'Xwé dídí',
      'address': 'Fi é xwé ɔ ɖée bǐ',
      'city': 'Toxɔ',
      'postal_code': 'Code postal',
      'gps_coords': 'GPS xó',
      'monthly_rent': 'Sun sun akwo',
      'sale_price': 'Xwé xisɔ akwo',
      'charges_incl': 'Charges ɖo mɛ à?',
      'charges_amount': 'Charges akwo',
      'deposit': 'Garantie akwo',
      'agency_fees': 'Agence akwo',
      'bedrooms': 'Damlɔ xá',
      'living_rooms': 'Jonɔ xá',
      'bathrooms': 'Lelɛ xwé',
      'toilets': 'Adado xwé',
      'kitchen_type': 'Adoxwé alɔkpa',
      'floor': 'Étage nabi',
      'elevator': 'Ascenseur',
      'parking': 'Parking',
      'garden_terrace': 'Jardin / Terrasse',
      'balcony': 'Balcon',
      'pets_allowed': 'Kanlin yí gbe à?',
      'smokers_allowed': 'Azɔ nu mɛ yí gbe à?',
      'min_lease': 'Sun nabi hudo',
      'notice_period': 'Wɛn nabi hudo',
      'availability': 'Fi é ɖée dìn',
      'certified_app': 'É nyɔ́ bǐ',
      'not_certified': 'É nyɔ́ ǎ',
      'apply_for_property': 'Yí gbe na xwé',
      'im_interested': 'Un jló',
      'edit': 'Línlín',
      'error_loading': 'Nǔ ɖé hwayi dìn',
      'retry': 'Vɔ sɔ kpɔ́n',
      'no_description': 'Xó ɖé kpò ǎ',
      'no_equipment': 'Nǔ ɖé kpò mɛ ǎ',
      'technical_sheet': 'Xwé sín wéma',
      'total_rooms': 'Xwé xá bǐ',
      'verified_by_app': 'HomeConnect ɖyí xwé ɔ',
      'comments_title': 'Xó le',
    }
  };

  User? get user => _user;
  User? get currentUser => _user; // Alias for AuthProvider migration
  bool get isLoading => _isLoading;
  String get error => _error;
  String get userDisplayName => _user?.displayName ?? '';
  String get userRole => _user?.role ?? '';
  bool get isAuthenticated => _user != null;
  bool get isVerified => _user?.isVerified ?? false;
  List<Property> get properties => _properties;  
  List<Property> get favorites => _favorites;
  bool get isDarkMode => _isDarkMode;
  Locale get locale => _locale;
  List<Map<String, dynamic>> get messages => _messages;
  
  bool get isProprietaire => _user?.role == 'proprietaire';
  bool get isLocataire => _user?.role == 'locataire';
  bool get isAdmin => _user?.role == 'admin';

  // Supported languages: fr, en, fon
  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  String translate(String key) {
    final lang = _locale.languageCode;
    return _translations[lang]?[key] ?? _translations['fr']?[key] ?? key;
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // Login direct — pas de checkConnectivity() préalable (évite un aller-retour inutile)
      final authData = await ApiService.login(email.trim().toLowerCase(), password);
      debugPrint('[Login] authData: $authData');

      if (authData == null) {
        _error = 'Email ou mot de passe incorrect.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final token = authData['token']?.toString();
      if (token == null || token.isEmpty) {
        _error = 'Réponse serveur invalide. Réessayez.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      ApiService.setToken(token);

      // Construire l'utilisateur depuis la réponse du serveur
      final raw = authData['user'];
      final userData = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final userRole = userData['role']?.toString() ?? 'locataire';
      final userId   = userData['id'] is int ? userData['id'] as int : 0;

      // Sauvegarder token en SharedPreferences — ne peut pas échouer
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('email', email.trim().toLowerCase());
      await prefs.setString('user_role', userRole);
      await prefs.setInt('user_id', userId);
      await prefs.setString('user_nom', userData['nom']?.toString() ?? '');
      await prefs.setString('user_prenom', userData['prenom']?.toString() ?? '');

      // Mise à jour cache local (erreurs ignorées — non bloquantes)
      try {
        final db = DatabaseHelper();
        final existing = await db.getUserByEmail(email.trim().toLowerCase());
        final dbData = {
          'nom':                 userData['nom']?.toString() ?? '',
          'prenom':              userData['prenom']?.toString() ?? '',
          'email':               email.trim().toLowerCase(),
          'password':            password,
          'telephone':           userData['telephone']?.toString() ?? '',
          'role':                userRole,
          'isVerified':          (userData['isVerified'] as num?)?.toInt() ?? 1,
          'verificationStatus':  userData['verificationStatus']?.toString() ?? 'certifie',
          'subscriptionType':    userData['subscriptionType']?.toString() ?? 'gratuit',
          'subscriptionExpiry':  userData['subscriptionExpiry']?.toString(),
          'rating':              (userData['rating'] as num?)?.toDouble() ?? 0.0,
          'reviewCount':         (userData['reviewCount'] as num?)?.toInt() ?? 0,
        };
        if (existing != null) {
          await db.updateUser(existing.id, dbData);
        } else {
          await db.addUser(dbData);
        }
        // Cache local en arrière-plan (non-bloquant)
        if (existing != null) { /* déjà fait */ } // ligne vide volontaire
      } catch (dbError) {
        debugPrint('[Login] DB cache error (non-bloquant): $dbError');
      }

      // TOUJOURS construire l'user depuis la réponse API pour avoir le vrai ID serveur
      // (évite les IDs SQLite locaux qui cassent la messagerie et les candidatures)
      _user = User(
        id:                 userId,
        nom:                userData['nom']?.toString() ?? '',
        prenom:             userData['prenom']?.toString() ?? '',
        email:              email.trim().toLowerCase(),
        telephone:          userData['telephone']?.toString() ?? '',
        role:               userRole,
        verificationStatus: userData['verificationStatus']?.toString() ?? 'certifie',
        subscriptionType:   userData['subscriptionType']?.toString() ?? 'gratuit',
        rating:             (userData['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount:        (userData['reviewCount'] as num?)?.toInt() ?? 0,
        isSubscriptionActive: true,
      );

      try { await _loadProperties(); } catch (_) {}

      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
      debugPrint('[Login] Exception: $e');
      _error = 'Connexion impossible : $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String nom,
    required String prenom,
    required String email,
    required String password,
    required String telephone,
    required String role,
    String? docIdentity,
    String? docAddress,
    String? docProperty,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final db = DatabaseHelper();
      
      // 1. Tenter l'inscription via l'API
      final serverError = await ApiService.registerWithError(
        email: email.trim().toLowerCase(),
        password: password,
        firstname: prenom,
        lastname: nom,
        role: role,
      );
      if (serverError != null) {
        // Traduire les messages Symfony en français
        if (serverError.toLowerCase().contains('already') || serverError.toLowerCase().contains('exist')) {
          _error = 'Cet email est déjà utilisé. Essayez de vous connecter ou utilisez un autre email.';
        } else if (serverError.contains('Impossible')) {
          _error = serverError;
        } else {
          _error = 'Inscription échouée : $serverError';
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Sauvegarder localement quoi qu'il arrive (pour le mode hors-ligne)
      final id = await db.addUser({
        'nom': nom,
        'prenom': prenom,
        'email': email,
        'password': password,
        'telephone': telephone,
        'role': role,
        'verificationDocument': docIdentity,
        'verificationDocumentAddress': docAddress,
        'verificationDocumentProperty': docProperty,
      });
      
      if (role == 'proprietaire') {
        final notifs = await db.getList('notifications');
        notifs.insert(0, {
          'id': DateTime.now().millisecondsSinceEpoch,
          'userId': 1, 
          'title': 'Nouvelle demande KYC',
          'body': 'Le propriétaire $prenom $nom a soumis ses documents.',
          'type': 'kyc_pending',
          'isRead': false,
          'createdAt': DateTime.now().toIso8601String(),
        });
        await db.setList('notifications', notifs);
      }

      _user = await db.getUserById(id);
      _isLoading = false;
      notifyListeners();

      // Déclencher un pull pour récupérer les IDs réels du serveur
      SyncService.pullFromBackend();

      return true;
    } catch (e) {
      _error = 'Erreur d\'inscription: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    // Nettoyer toutes les données locales pour éviter les fuites entre comptes
    try {
      final prefs = await SharedPreferences.getInstance();
      // Supprimer les clés de session
      await prefs.remove('token');
      await prefs.remove('email');
      await prefs.remove('user_role');
      await prefs.remove('user_id');
      await prefs.remove('user_nom');
      await prefs.remove('user_prenom');
      // Supprimer le cache de données partagé (évite que le prochain user voit les données de l'ancien)
      await prefs.remove('users');
      await prefs.remove('properties');
      await prefs.remove('messages');
      await prefs.remove('applications');
      await prefs.remove('notifications');
      await prefs.remove('favorites');
      await prefs.remove('tickets');
    } catch (e) {
      debugPrint('SharedPreferences clear failed: $e');
    }

    _user = null;
    _properties.clear();
    ApiService.clearToken();
    notifyListeners();
  }

  Future<void> _loadProperties() async {
    if (_user == null) return;
    if (_user!.role == 'proprietaire') {
      final db = DatabaseHelper();
      final data = await db.getPropertiesForOwner(_user!.id);
      _properties = data.map((e) => Property.fromMap(e)).toList();
    } else {
      // Locataire/admin : récupérer les biens actifs depuis l'API (pas SQLite)
      try {
        final raw = await ApiService.getProperties();
        _properties = raw.map((p) => Property.fromApiMap(Map<String, dynamic>.from(p))).toList();
      } catch (_) {
        final db = DatabaseHelper();
        _properties = await db.getProperties(status: 'actif');
      }
    }
    notifyListeners();
  }

  Future<void> refreshProperties() => _loadProperties();

  Future<bool> checkAuthStatus() async {
    try {
      if (_user == null) return false;
      // Ne pas écraser _user depuis SQLite — on garde le vrai ID serveur
      // Juste vérifier que le token est encore présent
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        _user = null;
        return false;
      }
      return true;
    } catch (e) {
      _error = 'Erreur de vérification: ${e.toString()}';
      return false;
    }
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }


  Future<void> loadChat(String userId, String receiverId) async {
    try {
      _messages = [];
      notifyListeners();
    } catch (e) {
      _error = 'Erreur de chargement du chat: $e';
      notifyListeners();
    }
  }

  Future<void> sendMessage(String userId, String receiverId, String text, String senderId) async {
    try {
      final message = {
        'userId': userId,
        'receiverId': receiverId,
        'text': text,
        'senderId': senderId,
        'timestamp': DateTime.now().toIso8601String(),
      };
      _messages.add(message);
      notifyListeners();
    } catch (e) {
      _error = 'Erreur d\'envoi du message: $e';
      notifyListeners();
    }
  }

  /// Ajoute un bien aux favoris
  Future<void> addFavorite(Property property) async {
    try {
      if (_user == null) return;
      if (!_favorites.any((p) => p.id == property.id)) {
        _favorites.add(property);
        final db = DatabaseHelper();
        await db.addFavorite(_user!.id, property.id);
        notifyListeners();
      }
    } catch (e) {
      _error = 'Erreur lors de l\'ajout aux favoris: $e';
      notifyListeners();
    }
  }

  /// Supprime un bien des favoris
  Future<void> removeFavorite(int propertyId) async {
    try {
      if (_user == null) return;
      _favorites.removeWhere((p) => p.id == propertyId);
      final db = DatabaseHelper();
      await db.removeFavorite(_user!.id, propertyId);
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors de la suppression du favori: $e';
      notifyListeners();
    }
  }
}