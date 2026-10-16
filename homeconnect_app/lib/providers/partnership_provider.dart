import 'package:flutter/foundation.dart';
import '../services/database_helper.dart';

/// Provider pour gérer les partenaires et les demandes de services
class PartnershipProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<Map<String, dynamic>> _partners = [];
  final List<Map<String, dynamic>> _serviceRequests = [];
  List<Map<String, dynamic>> _contactRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Map<String, dynamic>> get partners => _partners;
  List<Map<String, dynamic>> get serviceRequests => _serviceRequests;
  List<Map<String, dynamic>> get contactRequests => _contactRequests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // === PARTENAIRES ===

  /// Charger tous les partenaires
  Future<void> loadPartners() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _db.getList('partners');
      _partners = data.cast<Map<String, dynamic>>();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur chargement partenaires: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger les partenaires par catégorie
  Future<List<Map<String, dynamic>>> loadPartnersByCategory(String category) async {
    try {
      await loadPartners();
      return _partners.where((p) => p['category'] == category).toList();
    } catch (e) {
      _errorMessage = 'Erreur filtrage: $e';
      notifyListeners();
      return [];
    }
  }

  /// Ajouter un partenaire (admin)
  Future<bool> addPartner({
    required String name,
    required String service,
    required String category,
    required String contact,
    required String? logo,
    String? description,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.addPartner({
        'name': name,
        'service': service,
        'category': category,
        'contact': contact,
        'logo': logo,
        'description': description,
        'rating': 0.0,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await loadPartners();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur ajout partenaire: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// === DEMANDES DE CONTACT ===

  /// Contacter un partenaire
  Future<bool> contactPartner({
    required int partnerId,
    required int userId,
    required String subject,
    required String message,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final contactRequest = {
        'partnerId': partnerId,
        'userId': userId,
        'subject': subject,
        'message': message,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'respondedAt': null,
      };

      final requests = await _db.getList('contact_requests');
      final newId = requests.isEmpty ? 1 : (requests.last['id'] as int) + 1;
      contactRequest['id'] = newId;

      requests.add(contactRequest);
      await _db.setList('contact_requests', requests);

      _contactRequests = requests.cast<Map<String, dynamic>>();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur envoi demande: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Charger les demandes de contact d'un partenaire
  Future<void> loadPartnerContactRequests(int partnerId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final requests = await _db.getList('contact_requests');
      _contactRequests = requests
          .where((r) => r['partnerId'] == partnerId)
          .cast<Map<String, dynamic>>()
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur chargement demandes: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Répondre à une demande de contact
  Future<bool> respondToContact({
    required int requestId,
    required String response,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final requests = await _db.getList('contact_requests');
      final index = requests.indexWhere((r) => r['id'] == requestId);
      if (index == -1) throw Exception('Demande non trouvée');

      requests[index]['response'] = response;
      requests[index]['status'] = 'responded';
      requests[index]['respondedAt'] = DateTime.now().toIso8601String();

      await _db.setList('contact_requests', requests);
      _contactRequests = requests.cast<Map<String, dynamic>>();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur réponse: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// === SERVICES SPÉCIALISÉS ===

  /// Charger services juridiques
  Future<List<Map<String, dynamic>>> loadLegalServices() async {
    return await loadPartnersByCategory('legal');
  }

  /// Charger services artisanaux
  Future<List<Map<String, dynamic>>> loadCraftsmanServices() async {
    return await loadPartnersByCategory('craftsman');
  }

  /// Charger services transport/déménagement
  Future<List<Map<String, dynamic>>> loadTransportServices() async {
    return await loadPartnersByCategory('transport');
  }

  /// Charger services paiement/loyer
  Future<List<Map<String, dynamic>>> loadPaymentServices() async {
    return await loadPartnersByCategory('payment');
  }

  /// === ÉVALUATIONS ===

  /// Noter un partenaire
  Future<bool> ratePartner({
    required int partnerId,
    required int userId,
    required double rating,
    required String? review,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final ratings = await _db.getList('partner_ratings');
      final newId = ratings.isEmpty ? 1 : (ratings.last['id'] as int) + 1;

      ratings.add({
        'id': newId,
        'partnerId': partnerId,
        'userId': userId,
        'rating': rating,
        'review': review,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await _db.setList('partner_ratings', ratings);

      // Mettre à jour la note moyenne du partenaire
      final avgRating = ratings
          .where((r) => r['partnerId'] == partnerId)
          .fold<double>(0, (sum, r) => sum + (r['rating'] as num))
          .toDouble();
      final count = ratings.where((r) => r['partnerId'] == partnerId).length;
      final newAvg = avgRating / count;

      final partnerIdx = _partners.indexWhere((p) => p['id'] == partnerId);
      if (partnerIdx != -1) {
        _partners[partnerIdx]['rating'] = newAvg;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur notation: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// === CATÉGORIES ===

  /// Catégories de services
  static const List<String> serviceCategories = [
    'legal',
    'craftsman',
    'transport',
    'payment',
  ];

  static const Map<String, String> categoryLabels = {
    'legal': 'Services juridiques',
    'craftsman': 'Plateforme artisanale',
    'transport': 'Déménagement & transport',
    'payment': 'Paiements sécurisés',
  };

  static const Map<String, String> categoryDescriptions = {
    'legal': 'Services juridiques et administratifs',
    'craftsman': 'Petits travaux et dépannage',
    'transport': 'Services de déménagement et transport',
    'payment': 'Gestion sécurisée des paiements de loyers',
  };
}
