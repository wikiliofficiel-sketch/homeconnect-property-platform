import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../models/locataire_models.dart';

/// Provider pour l'aide et le support (partagé entre locataires et propriétaires)
class SupportProvider extends ChangeNotifier {
  late List<HelpCategory> _categories;
  late List<Tutorial> _tutorials;
  bool _isLoading = false;
  String _error = '';
  String _successMessage = '';

  List<HelpCategory> get categories => _categories;
  List<Tutorial> get tutorials => _tutorials;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get successMessage => _successMessage;

  SupportProvider() {
    _initializeFAQ();
    _initializeTutorials();
  }

  void _initializeTutorials() {
    _tutorials = [
      const Tutorial(
        id: 1,
        titre: 'Envoyer un message texte, vocal ou vidéo',
        categorie: 'Messagerie',
        steps: [
          TutorialStep(action: 'Texte', description: 'Ouvrez une discussion → tapez votre message → appuyez sur l’icône ➤.'),
          TutorialStep(action: 'Vocal', description: 'Maintenez enfoncé le micro. Glissez vers le haut pour verrouiller. Appuyez sur ⏸ pour pause, ▶️ pour reprendre.'),
          TutorialStep(action: 'Vidéo', description: 'Maintenez enfoncé l’icône appareil photo. Relâchez pour envoyer une vidéo courte.'),
        ],
      ),
      const Tutorial(
        id: 2,
        titre: 'Partager une image, vidéo ou document',
        categorie: 'Partage',
        steps: [
          TutorialStep(action: 'Depuis le chat', description: 'Appuyez sur 📎 → choisissez Galerie ou Document → sélectionnez → envoyez.'),
          TutorialStep(action: 'Depuis une autre app', description: 'Ouvrez le fichier → Partager → choisissez WhatsApp → destinataire.'),
        ],
      ),
      const Tutorial(
        id: 3,
        titre: 'Photo/vidéo « affichage unique »',
        categorie: 'Confidentialité',
        steps: [
          TutorialStep(action: 'Sélection', description: 'Appuyez sur 📎 → Appareil photo ou galerie.'),
          TutorialStep(action: 'Activation', description: 'Avant d’envoyer, appuyez sur le cercle avec ① en bas à droite.'),
          TutorialStep(action: 'Envoi', description: 'Le contenu disparaît après une seule vue.'),
        ],
      ),
      const Tutorial(
        id: 4,
        titre: 'Partager sa position en direct',
        categorie: 'Communication',
        steps: [
          TutorialStep(action: 'Accès', description: 'Appuyez sur 📎 → Position.'),
          TutorialStep(action: 'Live', description: 'Choisissez "Partager le live" pour un suivi en continu.'),
          TutorialStep(action: 'Durée', description: 'Sélectionnez 15 min, 1 h ou 8 h.'),
        ],
      ),
      const Tutorial(
        id: 5,
        titre: 'Formater un message (Gras, Italique...)',
        categorie: 'Messagerie',
        steps: [
          TutorialStep(action: 'Gras', description: 'Entourez de *astérisques* : *bonjour*'),
          TutorialStep(action: 'Italique', description: 'Entourez de _soulignés_ : _texte_'),
          TutorialStep(action: 'Barré', description: 'Entourez de ~tildes~ : ~texte~'),
          TutorialStep(action: 'Monospace', description: 'Entourez de ```accents graves```.'),
        ],
      ),
      const Tutorial(
        id: 6,
        titre: 'Créer un sondage',
        categorie: 'Groupes',
        steps: [
          TutorialStep(action: 'Accès', description: 'Dans un groupe, appuyez sur 📎 → Sondage.'),
          TutorialStep(action: 'Question', description: 'Tapez votre question (max 255 car.).'),
          TutorialStep(action: 'Options', description: 'Ajoutez jusqu’à 12 options.'),
        ],
      ),
    ];
  }

  void loadSupportContent({required String role}) {
    // On pourrait filtrer les FAQ ici selon le rôle
    _initializeFAQ();
    notifyListeners();
  }

  void _initializeFAQ() {
    _categories = [
      const HelpCategory(
        id: 1,
        titre: 'Messagerie et partage',
        description: 'Échangez et partagez du contenu de manière riche',
        icon: 'message',
        items: [
          FAQItem(
            id: 1,
            question: 'Messages texte, vocaux et vidéo',
            reponse: 'Envoyez des messages instantanés, des notes vocales et des messages vidéo. Vous pouvez faire une pause lors de l\'enregistrement d\'un message vocal et le réécouter à 1x, 1.5x ou 2x.',
          ),
          FAQItem(
            id: 2,
            question: 'Partage enrichi',
            reponse: 'Partagez des images, des vidéos, des documents (PDF, etc.), votre position en direct, ou des contacts.',
          ),
          FAQItem(
            id: 3,
            question: 'Contenu éphémère',
            reponse: 'Mode "Affichage unique" pour les médias ou "Messages éphémères" s\'effaçant après 24h, 7j ou 90j.',
          ),
          FAQItem(
            id: 4,
            question: 'Sondages',
            reponse: 'Créez des sondages dans une discussion de groupe avec jusqu\'à 12 options. Les résultats sont visibles en temps réel.',
          ),
          FAQItem(
            id: 5,
            question: 'Statuts des messages (Coches)',
            reponse: '⏳ : Envoi en cours. ✓ : Envoyé aux serveurs. ✓✓ gris : Reçu par le correspondant. ✓✓ bleu : Lu par le correspondant.',
          ),
          FAQItem(
            id: 6,
            question: 'Lire sans être vu (discrètement)',
            reponse: 'Astuces : lisez depuis les notifications, utilisez le mode Avion avant d\'ouvrir l\'app, ou désactivez les "Confirmations de lecture" dans les paramètres.',
          ),
        ],
      ),
      const HelpCategory(
        id: 2,
        titre: 'Appels et communication',
        description: 'Appels de haute qualité et fonctionnalités riches',
        icon: 'call',
        items: [
          FAQItem(
            id: 1,
            question: 'Appels individuels et de groupe',
            reponse: 'Passez des appels audio et vidéo. Les appels vidéo de groupe accueillent jusqu\'à 32 participants.',
          ),
          FAQItem(
            id: 2,
            question: 'Partage d\'écran et réduction de bruit',
            reponse: 'Montrez votre écran lors d\'un appel vidéo. La suppression du bruit de fond améliore l\'audio automatiquement.',
          ),
          FAQItem(
            id: 3,
            question: 'Chats vocaux',
            reponse: 'Salons vocaux persistants dans les groupes pour discuter sans déranger tout le monde par une sonnerie.',
          ),
        ],
      ),
      const HelpCategory(
        id: 3,
        titre: 'Groupes et communautés',
        description: 'Organisez vos conversations à grande échelle',
        icon: 'groups',
        items: [
          FAQItem(
            id: 1,
            question: 'Communautés',
            reponse: 'Rassemblez plusieurs groupes en un seul espace, idéal pour les clubs, écoles ou entreprises.',
          ),
          FAQItem(
            id: 2,
            question: 'Canaux WhatsApp',
            reponse: 'Suivez des personnalités ou organisations pour recevoir des infos. Votre numéro n\'est pas visible.',
          ),
          FAQItem(
            id: 3,
            question: 'Événements et Rappels',
            reponse: 'Créez des événements avec rappel automatique 24h et 1h avant pour les membres du groupe.',
          ),
        ],
      ),
      const HelpCategory(
        id: 4,
        titre: 'Confidentialité et sécurité',
        description: 'Protection de vos échanges par chiffrement',
        icon: 'security',
        items: [
          FAQItem(
            id: 1,
            question: 'Vérification en deux étapes',
            reponse: 'Sécurisez votre compte avec un code PIN et un courriel de récupération.',
          ),
          FAQItem(
            id: 2,
            question: 'Clés d\'accès (Passkeys)',
            reponse: 'Connectez-vous via empreinte digitale ou reconnaissance faciale.',
          ),
          FAQItem(
            id: 3,
            question: 'Verrouillage des discussions',
            reponse: 'Protégez vos discussions sensibles derrière un code secret ou la biométrie.',
          ),
        ],
      ),
      const HelpCategory(
        id: 5,
        titre: 'Intelligence Artificielle',
        description: 'L\'IA au service de vos conversations',
        icon: 'smart_toy',
        items: [
          FAQItem(
            id: 1,
            question: 'Meta AI : Retouche photo',
            reponse: 'Retouchez vos photos avant envoi (changer l\'arrière-plan, appliquer un style) grâce à Meta AI.',
          ),
          FAQItem(
            id: 2,
            question: 'Aide à l\'écriture et Résumés',
            reponse: 'Suggestions de réponses contextuelles et résumés automatiques des messages non lus.',
          ),
          FAQItem(
            id: 3,
            question: 'Traduction instantanée',
            reponse: 'Traduisez des messages d\'un simple appui directement dans la discussion.',
          ),
        ],
      ),
      const HelpCategory(
        id: 6,
        titre: 'Gestion du compte',
        description: 'Gérez votre compte sur plusieurs appareils',
        icon: 'settings',
        items: [
          FAQItem(
            id: 1,
            question: 'Multi-appareils',
            reponse: 'Utilisez WhatsApp sur jusqu\'à 4 appareils supplémentaires, même si votre téléphone principal est éteint.',
          ),
          FAQItem(
            id: 2,
            question: 'Multi-comptes',
            reponse: 'Gérez deux comptes distincts (perso et pro) simultanément sur un même téléphone.',
          ),
          FAQItem(
            id: 3,
            question: 'Transfert d\'historique',
            reponse: 'Transférez facilement vos discussions entre Android et iPhone.',
          ),
        ],
      ),
      const HelpCategory(
        id: 7,
        titre: 'Business et outils pro',
        description: 'Solutions pour les professionnels et entreprises',
        icon: 'business',
        items: [
          FAQItem(
            id: 1,
            question: 'Profil professionnel',
            reponse: 'Créez un profil avec description, adresse, horaires et catalogue de produits.',
          ),
          FAQItem(
            id: 2,
            question: 'Outils de communication',
            reponse: 'Messages d\'absence, messages de bienvenue et étiquettes pour organiser vos clients.',
          ),
        ],
      ),
      const HelpCategory(
        id: 8,
        titre: 'Fonctionnalités diverses',
        description: 'Personnalisation et astuces supplémentaires',
        icon: 'auto_awesome',
        items: [
          FAQItem(
            id: 1,
            question: 'Statuts',
            reponse: 'Publiez des textes, photos ou vidéos qui disparaissent au bout de 24 heures.',
          ),
          FAQItem(
            id: 2,
            question: 'Icônes et thèmes personnalisés',
            reponse: 'Bientôt disponible : personnalisez entièrement l\'apparence avec des thèmes et icônes.',
          ),
        ],
      ),
    ];
  }

  /// Submit contact form
  Future<bool> submitContact({
    required String email,
    required String sujet,
    required String message,
    required String userRole,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final db = DatabaseHelper();
      
      // Create real ticket
      await db.addTicket({
        'email': email,
        'sujet': sujet,
        'message': message,
        'type': 'aide',
        'role': userRole,
      });

      // 🔔 Notifier l'administrateur
      await NotificationService.addNotification(
        userId: 1, // ID de l'admin
        title: 'Nouveau message de support ($userRole)',
        body: 'Sujet : $sujet',
        type: 'support_request',
      );

      _successMessage =
          'Message envoyé avec succès. Nous vous répondrons dans les 48h à $email.';
      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _error = 'Erreur envoi: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearMessages() {
    _error = '';
    _successMessage = '';
    notifyListeners();
  }
}
