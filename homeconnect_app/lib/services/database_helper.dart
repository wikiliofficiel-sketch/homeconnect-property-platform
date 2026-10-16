import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/property.dart';
import '../models/extended_models.dart';
import 'sync_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  Future<void> _init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    await _initData();
  }

  void _triggerSync() {
    SyncService.autoSync();
  }

  /// Synchroniser les données locales avec le backend Symfony
  Future<bool> syncToBackend() async {
    await SyncService.autoSync();
    return true; // Simplified for now
  }

  /// Enregistrer les données récupérées de Symfony en local
  Future<bool> saveBulkData(Map<String, dynamic> data) async {
    try {
      await _init();
      if (data.containsKey('users')) {
        await _prefs.setString('users', jsonEncode(data['users']));
      }
      if (data.containsKey('properties')) {
        await _prefs.setString('properties', jsonEncode(data['properties']));
      }
      if (data.containsKey('applications')) {
        await _prefs.setString('applications', jsonEncode(data['applications']));
      }
      if (data.containsKey('messages')) {
        final List<dynamic> rawMessages = data['messages'];
        final List<Map<String, dynamic>> formattedMessages = [];
        final List<dynamic> localUsers = jsonDecode(_prefs.getString('users') ?? '[]');

        for (var msg in rawMessages) {
          if (msg is! Map) continue;
          
          int? senderId = msg['senderId'] is int ? msg['senderId'] : null;
          int? receiverId = msg['receiverId'] is int ? msg['receiverId'] : null;

          // Si IDs absents (format Symfony pur), on cherche via les emails
          if (senderId == null && msg['sender'] != null) {
            final email = msg['sender']['email'];
            try {
              senderId = localUsers.firstWhere((u) => u['email'] == email)['id'];
            } catch (_) {}
          }
          if (receiverId == null && msg['receiver'] != null) {
            final email = msg['receiver']['email'];
            try {
              receiverId = localUsers.firstWhere((u) => u['email'] == email)['id'];
            } catch (_) {}
          }

          formattedMessages.add({
            'id': msg['id'],
            'senderId': senderId ?? 0,
            'receiverId': receiverId ?? 0,
            'text': msg['text'] ?? msg['content'] ?? '',
            'timestamp': msg['timestamp'] ?? msg['createdAt'] ?? DateTime.now().toIso8601String(),
            'read': msg['read'] ?? msg['isRead'] ?? false,
          });
        }
        await _prefs.setString('messages', jsonEncode(formattedMessages));
      }
      if (data.containsKey('notifications')) {
        await _prefs.setString('notifications', jsonEncode(data['notifications']));
      }
      if (data.containsKey('tickets')) {
        await _prefs.setString('tickets', jsonEncode(data['tickets']));
      }
      if (data.containsKey('favorites')) {
        await _prefs.setString('favorites', jsonEncode(data['favorites']));
      }
      if (data.containsKey('comments')) {
        await _prefs.setString('comments', jsonEncode(data['comments']));
      }
      if (data.containsKey('property_interactions')) {
        await _prefs.setString('property_interactions', jsonEncode(data['property_interactions']));
      }
      if (data.containsKey('rentals')) {
        await _prefs.setString('rentals', jsonEncode(data['rentals']));
      }
      if (data.containsKey('subscriptions')) {
        await _prefs.setString('subscriptions', jsonEncode(data['subscriptions']));
      }
      if (data.containsKey('reports')) {
        await _prefs.setString('reports', jsonEncode(data['reports']));
      }
      if (data.containsKey('reviews')) {
        await _prefs.setString('reviews', jsonEncode(data['reviews']));
      }
      return true;
    } catch (e) {
      debugPrint('Erreur saveBulkData: $e');
      return false;
    }
  }

  Future<User?> getAdminUser() async {
    final users = await getAllUsers();
    try {
      return users.firstWhere((u) => u.email == 'admin@homeconnect.com');
    } catch (_) {
      return null;
    }
  }

  Future<void> _initData() async {
    // Toujours s'assurer que l'admin par défaut existe avec le bon mot de passe
    final List<dynamic> users = jsonDecode(_prefs.getString('users') ?? '[]');
    bool adminExists = false;
    
    for (int i = 0; i < users.length; i++) {
      if (users[i]['email'] == 'admin@homeconnect.com') {
        // Mettre à jour le mot de passe s'il a changé
        users[i]['password'] = 'admin123';
        users[i]['role'] = 'admin';
        adminExists = true;
        break;
      }
    }

    if (!adminExists) {
      final admin = {
        'id': 1,
        'nom': 'Admin',
        'prenom': 'Super',
        'email': 'admin@homeconnect.com',
        'password': 'admin123',
        'telephone': '+229 90000000',
        'role': 'admin',
        'isVerified': 1,
        'verificationStatus': 'certifie',
        'subscriptionType': null,
        'subscriptionExpiry': null,
        'rating': null,
        'reviewCount': null,
      };
      users.add(admin);
    }
    
    await _prefs.setString('users', jsonEncode(users));
    if (!_prefs.containsKey('properties')) await _prefs.setString('properties', jsonEncode([]));
    if (!_prefs.containsKey('applications')) await _prefs.setString('applications', jsonEncode([]));
    if (!_prefs.containsKey('scheduled_visits')) await _prefs.setString('scheduled_visits', jsonEncode([]));
    if (!_prefs.containsKey('utility_inspections')) await _prefs.setString('utility_inspections', jsonEncode([]));
    if (!_prefs.containsKey('subscriptions')) await _prefs.setString('subscriptions', jsonEncode([]));
    if (!_prefs.containsKey('evaluations')) await _prefs.setString('evaluations', jsonEncode([]));
    if (!_prefs.containsKey('property_stats')) await _prefs.setString('property_stats', jsonEncode([]));
    if (!_prefs.containsKey('favorites')) await _prefs.setString('favorites', jsonEncode([]));
    if (!_prefs.containsKey('reports')) await _prefs.setString('reports', jsonEncode([]));
    if (!_prefs.containsKey('reviews')) await _prefs.setString('reviews', jsonEncode([]));
    if (!_prefs.containsKey('partners') || (_prefs.getString('partners') ?? '[]') == '[]') {
      final defaultPartners = [
        {
          'id': 1,
          'name': 'Déménage Express',
          'service': 'Déménagement & Transport',
          'description': 'Experts en déménagement résidentiel et transport de meubles sur tout le Bénin.',
          'contact': '+229 97000001',
          'email': 'contact@demenage.bj',
          'type': 'moving'
        },
        {
          'id': 2,
          'name': 'Maître Azon',
          'service': 'Services Juridiques',
          'description': 'Conseils juridiques immobiliers et rédaction de contrats de bail sécurisés.',
          'contact': '+229 96000002',
          'email': 'info@azon-legal.bj',
          'type': 'legal'
        },
        {
          'id': 3,
          'name': 'Bénin Artisans',
          'service': 'Réparation & Maintenance',
          'description': 'Plomberie, électricité et maçonnerie pour l\'entretien de vos biens.',
          'contact': '+229 95000003',
          'email': 'artisans@benin.bj',
          'type': 'craft'
        },
        {
          'id': 4,
          'name': 'FedaPay Secure',
          'service': 'Paiement des Loyers',
          'description': 'Solution sécurisée pour collecter vos loyers via Mobile Money et Carte.',
          'contact': '+229 94000004',
          'email': 'support@fedapay.com',
          'type': 'payment'
        }
      ];
      await _prefs.setString('partners', jsonEncode(defaultPartners));
    }
    if (!_prefs.containsKey('partner_services')) await _prefs.setString('partner_services', jsonEncode([]));
    if (!_prefs.containsKey('service_requests')) await _prefs.setString('service_requests', jsonEncode([]));
    if (!_prefs.containsKey('notifications')) await _prefs.setString('notifications', jsonEncode([]));
    final communityData = _prefs.getString('community_posts');
    if (communityData == null || communityData == '[]') {
      final posts = [
        {
          'id': 1,
          'authorId': 1,
          'authorName': 'Admin Support',
          'content': 'Bienvenue dans la communauté ImmoBénin ! Ici, vous pouvez échanger sur vos expériences de location.',
          'date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          'comments': [
            {
              'id': 1,
              'authorId': 2,
              'authorName': 'Koffi Paul',
              'content': 'Super initiative, merci !',
              'date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
            }
          ],
        },
        {
          'id': 2,
          'authorId': 3,
          'authorName': 'Marie Claire',
          'content': 'Est-ce que quelqu\'un connaît un bon déménageur sur Cotonou ?',
          'date': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
          'comments': [],
        }
      ];
      await _prefs.setString('community_posts', jsonEncode(posts));
    }
    if (!_prefs.containsKey('commissions')) await _prefs.setString('commissions', jsonEncode([]));
    if (!_prefs.containsKey('kyc_documents')) await _prefs.setString('kyc_documents', jsonEncode([]));
    if (!_prefs.containsKey('admin_sanctions')) await _prefs.setString('admin_sanctions', jsonEncode([]));
    if (!_prefs.containsKey('commission_records')) await _prefs.setString('commission_records', jsonEncode([]));
    if (!_prefs.containsKey('logs')) await _prefs.setString('logs', jsonEncode([]));
    if (!_prefs.containsKey('settings')) await _prefs.setString('settings', jsonEncode([]));
    if (!_prefs.containsKey('messages')) await _prefs.setString('messages', jsonEncode([]));
    if (!_prefs.containsKey('contracts')) await _prefs.setString('contracts', jsonEncode([]));
    if (!_prefs.containsKey('transactions')) await _prefs.setString('transactions', jsonEncode([]));
    if (!_prefs.containsKey('tickets')) await _prefs.setString('tickets', jsonEncode([]));
  }

  Future<void> clearAllData() async {
    await _init();
    await _prefs.remove('users');
    await _prefs.remove('properties');
    await _prefs.remove('applications');
    await _prefs.remove('favorites');
    await _prefs.remove('reports');
    await _prefs.remove('reviews');
    await _prefs.remove('partners');
    await _prefs.remove('partner_services');
    await _prefs.remove('service_requests');
    await _prefs.remove('notifications');
    await _prefs.remove('community_posts');
    await _prefs.remove('commissions');
    await _prefs.remove('kyc_documents');
    await _prefs.remove('admin_sanctions');
    await _prefs.remove('commission_records');
    await _prefs.remove('logs');
    await _prefs.remove('settings');
    await _prefs.remove('messages');
    _isInitialized = false;
    await _init();
  }

  Future<List<dynamic>> getList(String key) async {
    await _init();
    final data = _prefs.getString(key);
    return data == null ? [] : jsonDecode(data);
  }

  Future<void> setList(String key, List<dynamic> list) async {
    await _init();
    await _prefs.setString(key, jsonEncode(list));
    _triggerSync(); // Déclenche la synchro immédiate vers le serveur
  }

  // ========== USERS ==========
  Future<List<User>> getAllUsers() async {
    final list = await getList('users');
    final result = <User>[];
    for (final e in list) {
      try {
        if (e is Map<String, dynamic>) {
          result.add(User.fromMap(e));
        } else if (e is Map) {
          result.add(User.fromMap(Map<String, dynamic>.from(e)));
        }
      } catch (err) {
        debugPrint('[DB] getAllUsers skip invalid entry: $err');
      }
    }
    return result;
  }

  Future<User?> getUserByEmail(String email) async {
    final users = await getAllUsers();
    try {
      return users.firstWhere((u) => u.email == email);
    } catch (_) {
      return null;
    }
  }

  Future<User?> getUserById(int id) async {
    final users = await getAllUsers();
    try {
      return users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<int> addUser(Map<String, dynamic> userData) async {
    final users = await getAllUsers();
    final newId = users.isEmpty ? 1 : users.map((u) => u.id).reduce((a, b) => a > b ? a : b) + 1;
    final newUser = {
      'id': newId,
      'nom': userData['nom'],
      'prenom': userData['prenom'],
      'email': userData['email'],
      'password': userData['password'],
      'telephone': userData['telephone'] ?? '',
      'role': userData['role'],
      'isVerified': 1,
      'verificationStatus': 'certifie',
      'verificationDocument': userData['verificationDocument'],
      'verificationDocumentAddress': userData['verificationDocumentAddress'],
      'verificationDocumentProperty': userData['verificationDocumentProperty'],
      'subscriptionType': 'gratuit',
      'subscriptionExpiry': null,
      'rating': null,
      'reviewCount': null,
    };
    final updatedUsers = [...users.map((u) => u.toMap()), newUser];
    await setList('users', updatedUsers);
    return newId;
  }

  Future<int> updateUser(int id, Map<String, dynamic> data) async {
    final users = await getAllUsers();
    final index = users.indexWhere((u) => u.id == id);
    if (index == -1) return 0;
    final updated = users[index].toMap();
    updated.addAll(data);
    final updatedUsers = List.from(users.map((u) => u.toMap()));
    updatedUsers[index] = updated;
    await setList('users', updatedUsers);
    return 1;
  }

  Future<int> upgradeSubscription(int userId, String type, int months) async {
    final expiry = DateTime.now().add(Duration(days: 30 * months));
    return await updateUser(userId, {
      'subscriptionType': type,
      'subscriptionExpiry': expiry.toIso8601String(),
    });
  }

  Future<int> deleteUser(int id) async {
    final users = await getAllUsers();
    final newList = users.where((u) => u.id != id).map((u) => u.toMap()).toList();
    await setList('users', newList);
    return 1;
  }

  Future<bool> resetPassword(String email, String newPassword) async {
    final user = await getUserByEmail(email);
    if (user == null) return false;
    await updateUser(user.id, {'password': newPassword});
    return true;
  }

  Future<int> getTotalUsers() async => (await getAllUsers()).length;
  Future<int> getProprietairesCount() async => (await getAllUsers()).where((u) => u.role == 'proprietaire').length;
  Future<int> getLocatairesCount() async => (await getAllUsers()).where((u) => u.role == 'locataire').length;
  Future<int> getActivePropertiesCount() async => (await getProperties(status: 'actif')).length;

  Future<List<User>> getSubscribedUsers() async {
    final all = await getAllUsers();
    return all.where((u) => u.subscriptionType == 'premium_plus').toList();
  }

  // ========== PROPERTIES ==========
  Future<List<Property>> getProperties({
    String? search,
    String? type,
    int? minPrice,
    int? maxPrice,
    String? status,
    bool? highlighted,
  }) async {
    final list = await getList('properties');
    var props = <Property>[];
    for (final e in list) {
      try {
        if (e is Map<String, dynamic>) {
          props.add(Property.fromMap(e));
        } else if (e is Map) {
          props.add(Property.fromMap(Map<String, dynamic>.from(e)));
        }
      } catch (err) {
        debugPrint('[DB] getProperties skip invalid entry: $err');
      }
    }

    if (status != null) props = props.where((p) => p.status == status).toList();
    if (search != null && search.isNotEmpty) {
      props = props.where((p) =>
        p.titre.toLowerCase().contains(search.toLowerCase()) ||
        p.lieu.toLowerCase().contains(search.toLowerCase())
      ).toList();
    }
    if (type != null && type != 'Tous') props = props.where((p) => p.type == type).toList();
    if (minPrice != null) props = props.where((p) => p.prix >= minPrice).toList();
    if (maxPrice != null) props = props.where((p) => p.prix <= maxPrice).toList();
    if (highlighted != null) props = props.where((p) => p.isHighlighted == highlighted).toList();

    return props;
  }

  Future<List<Map<String, dynamic>>> getPropertiesForOwner(int ownerId) async {
    final props = await getProperties(status: null);
    return props.where((p) => p.proprietaireId == ownerId).map((p) => p.toMap()).toList();
  }

  Future<Map<String, dynamic>> getPropertyById(int id) async {
    final props = await getProperties(status: null);
    try {
      final prop = props.firstWhere((p) => p.id == id);
      await incrementViews(id);
      return prop.toMap();
    } catch (_) {
      return {};
    }
  }

  Future<int> addProperty(Map<String, dynamic> data) async {
    final props = await getProperties(status: null);
    final users = await getAllUsers();
    
    // Trouver l'email du propriétaire pour la synchronisation
    String ownerEmail = 'admin@homeconnect.com';
    try {
      final owner = users.firstWhere((u) => u.id == data['proprietaireId']);
      ownerEmail = owner.email;
    } catch (_) {}

    final newId = props.isEmpty ? 1 : props.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1;
    final newProp = {
      'id': newId,
      'titre': data['titre'],
      'lieu': data['lieu'],
      'prix': data['prix'],
      'pieces': data['pieces'] ?? 0,
      'type': data['type'] ?? 'Appartement',
      'rating': 0.0,
      'imageUrl': data['imageUrl'],
      'description': data['description'],
      'descriptionDetaillee': data['descriptionDetaillee'],
      'videoUrl': data['videoUrl'],
      'additionalImages': data['additionalImages'] ?? [],
      'proprietaireId': data['proprietaireId'],
      'proprietaireEmail': ownerEmail, // Ajouté pour la synchro Symfony
      'status': data['status'] ?? 'en_attente',
      'verified': 0,
      'views': 0,
      'reports': 0,
      'likes': 0,
      'dislikes': 0,
      'commentsCount': 0,
      'isReserved': 0,
      'isHighlighted': 0,
      'highlightedUntil': null,
      'createdAt': DateTime.now().toIso8601String(),
      'statutAnnonce': data['statutAnnonce'] ?? 'À louer',
      'superficie': data['superficie'] ?? 0.0,
      'ville': data['ville'] ?? '',
      'codePostal': data['codePostal'],
      'prixVente': data['prixVente'],
      'chargesComprises': data['chargesComprises'] ?? 0,
      'montantCharges': data['montantCharges'],
      'depotGarantie': data['depotGarantie'],
      'fraisAgence': data['fraisAgence'],
      'nbChambres': data['nbChambres'] ?? 0,
      'nbSalons': data['nbSalons'] ?? 0,
      'nbSallesDeBain': data['nbSallesDeBain'] ?? 0,
      'nbToilettes': data['nbToilettes'] ?? 0,
      'typeCuisine': data['typeCuisine'] ?? 'Non équipée',
      'etage': data['etage'],
      'hasAscenseur': data['hasAscenseur'] ?? 0,
      'hasParking': data['hasParking'] ?? 0,
      'parkingPlaces': data['parkingPlaces'] ?? 0,
      'hasJardin': data['hasJardin'] ?? 0,
      'hasBalcon': data['hasBalcon'] ?? 0,
      'equipements': data['equipements'] ?? [],
      'planUrl': data['planUrl'],
      'animauxAcceptes': data['animauxAcceptes'] ?? 0,
      'fumeursAcceptes': data['fumeursAcceptes'] ?? 0,
      'dureeMinLocation': data['dureeMinLocation'],
      'preavis': data['preavis'],
      'disponibilite': data['disponibilite'],
    };
    final updated = [...props.map((p) => p.toMap()), newProp];
    await setList('properties', updated);
    
    _triggerSync();

    return newId;
  }

  Future<int> updateProperty(int id, Map<String, dynamic> data) async {
    final props = await getProperties(status: null);
    final index = props.indexWhere((p) => p.id == id);
    if (index == -1) return 0;
    final updated = props[index].toMap();
    updated.addAll(data);
    final updatedList = List.from(props.map((p) => p.toMap()));
    updatedList[index] = updated;
    await setList('properties', updatedList);
    _triggerSync();
    return 1;
  }

  Future<int> deleteProperty(int id) async {
    final props = await getProperties(status: null);
    final newList = props.where((p) => p.id != id).map((p) => p.toMap()).toList();
    await setList('properties', newList);
    _triggerSync();
    return 1;
  }

  Future<int> incrementViews(int id) async {
    final props = await getProperties(status: null);
    final index = props.indexWhere((p) => p.id == id);
    if (index == -1) return 0;
    final updated = props[index].toMap();
    updated['views'] = (updated['views'] as int) + 1;
    final updatedList = List.from(props.map((p) => p.toMap()));
    updatedList[index] = updated;
    await setList('properties', updatedList);
    return 1;
  }

  // ========== INTERACTIONS (LIKES/FAVORIS) ==========

  Future<bool> toggleLike(int propertyId, int userId) async {
    final interactions = await getList('property_interactions');
    final props = await getProperties(status: null);
    final propIndex = props.indexWhere((p) => p.id == propertyId);
    if (propIndex == -1) return false;

    final existing = interactions.indexWhere((i) => i['propertyId'] == propertyId && i['userId'] == userId && i['type'] == 'like');

    if (existing != -1) {
      // Retirer le like
      interactions.removeAt(existing);
      final currentLikes = interactions.where((i) => i['propertyId'] == propertyId && i['type'] == 'like').length;
      final currentDislikes = interactions.where((i) => i['propertyId'] == propertyId && i['type'] == 'dislike').length;
      await updateProperty(propertyId, {'likes': currentLikes, 'dislikes': currentDislikes});
      await setList('property_interactions', interactions);
      return false; // Not liked anymore
    } else {
      // Ajouter le like et retirer le dislike si présent
      interactions.removeWhere((i) => i['propertyId'] == propertyId && i['userId'] == userId && i['type'] == 'dislike');
      
      interactions.add({
        'propertyId': propertyId,
        'userId': userId,
        'type': 'like',
        'createdAt': DateTime.now().toIso8601String(),
      });
      
      final currentLikes = interactions.where((i) => i['propertyId'] == propertyId && i['type'] == 'like').length;
      final currentDislikes = interactions.where((i) => i['propertyId'] == propertyId && i['type'] == 'dislike').length;
      await updateProperty(propertyId, {
        'likes': currentLikes,
        'dislikes': currentDislikes,
      });
      
      await setList('property_interactions', interactions);
      
      // Notification au propriétaire
      if (propIndex != -1) {
        final propOwnerId = props[propIndex].proprietaireId;
        final propTitle = props[propIndex].titre;
        final user = await getUserById(userId);
        final userName = user?.displayName ?? 'Un utilisateur';
        await addNotification(propOwnerId, 'Nouveau J\'aime', '$userName a aimé votre bien "$propTitle"', 'like');
      }

      return true; // Liked
    }
  }

  Future<bool> toggleDislike(int propertyId, int userId) async {
    final interactions = await getList('property_interactions');
    final props = await getProperties(status: null);
    final propIndex = props.indexWhere((p) => p.id == propertyId);
    if (propIndex == -1) return false;

    final existing = interactions.indexWhere((i) => i['propertyId'] == propertyId && i['userId'] == userId && i['type'] == 'dislike');

    if (existing != -1) {
      interactions.removeAt(existing);
      final currentLikes = interactions.where((i) => i['propertyId'] == propertyId && i['type'] == 'like').length;
      final currentDislikes = interactions.where((i) => i['propertyId'] == propertyId && i['type'] == 'dislike').length;
      await updateProperty(propertyId, {'likes': currentLikes, 'dislikes': currentDislikes});
      await setList('property_interactions', interactions);
      return false;
    } else {
      interactions.removeWhere((i) => i['propertyId'] == propertyId && i['userId'] == userId && i['type'] == 'like');
      interactions.add({
        'propertyId': propertyId,
        'userId': userId,
        'type': 'dislike',
        'createdAt': DateTime.now().toIso8601String(),
      });
      final currentLikes = interactions.where((i) => i['propertyId'] == propertyId && i['type'] == 'like').length;
      final currentDislikes = interactions.where((i) => i['propertyId'] == propertyId && i['type'] == 'dislike').length;
      await updateProperty(propertyId, {'likes': currentLikes, 'dislikes': currentDislikes});
      await setList('property_interactions', interactions);
      return true;
    }
  }

  Future<Map<String, bool>> getUserInteractions(int propertyId, int userId) async {
    final interactions = await getList('property_interactions');
    final like = interactions.any((i) => i['propertyId'] == propertyId && i['userId'] == userId && i['type'] == 'like');
    final dislike = interactions.any((i) => i['propertyId'] == propertyId && i['userId'] == userId && i['type'] == 'dislike');
    return {'liked': like, 'disliked': dislike};
  }

  Future<int> getPropertyReportsCount(int propertyId) async {
    final reports = await getList('reports');
    return reports.where((r) => r['propertyId'] == propertyId).length;
  }

  // ========== FAVORITES ==========
  Future<List<Property>> getFavorites(int locataireId) async {
    final favs = await getList('favorites');
    final propertyIds = favs.where((f) => f['locataireId'] == locataireId).map((f) => f['propertyId'] as int).toList();
    final allProps = await getProperties(status: null);
    return allProps.where((p) => propertyIds.contains(p.id)).toList();
  }

  Future<int> addFavorite(int locataireId, int propertyId) async {
    final favs = await getList('favorites');
    if (favs.any((f) => f['locataireId'] == locataireId && f['propertyId'] == propertyId)) return 0;
    favs.add({'locataireId': locataireId, 'propertyId': propertyId});
    await setList('favorites', favs);
    
    // Notification au propriétaire
    final props = await getProperties(status: null);
    final propIndex = props.indexWhere((p) => p.id == propertyId);
    if (propIndex != -1) {
      final propOwnerId = props[propIndex].proprietaireId;
      final propTitle = props[propIndex].titre;
      final user = await getUserById(locataireId);
      final userName = user?.displayName ?? 'Un utilisateur';
      await addNotification(propOwnerId, 'Nouveau Favori', '$userName a ajouté votre bien "$propTitle" à ses favoris', 'favorite');
    }

    return 1;
  }


  Future<int> removeFavorite(int locataireId, int propertyId) async {
    final favs = await getList('favorites');
    favs.removeWhere((f) => f['locataireId'] == locataireId && f['propertyId'] == propertyId);
    await setList('favorites', favs);
    return 1;
  }

  // ========== APPLICATIONS ==========
  Future<List<Map<String, dynamic>>> getApplicationsForLocataire(int locataireId) async {
    final apps = await getList('applications');
    return apps.where((a) => a['locataireId'] == locataireId).cast<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getApplicationsForProprietaire(int proprietaireId) async {
    final apps = await getList('applications');
    final props = await getPropertiesForOwner(proprietaireId);
    final propIds = props.map((p) => p['id'] as int).toList();
    final users = await getAllUsers();
    
    final filteredApps = apps.where((a) => propIds.contains(a['propertyId'])).cast<Map<String, dynamic>>().toList();
    
    // Enrich with user info
    for (var app in filteredApps) {
      final locataireId = app['locataireId'] as int;
      final user = users.firstWhere((u) => u.id == locataireId, orElse: () => User(id: locataireId, nom: 'Inconnu', prenom: '', email: '', password: '', telephone: '', role: 'locataire'));
      app['locataireNom'] = user.nom;
      app['locatairePrenom'] = user.prenom;
    }
    
    return filteredApps;
  }

  Future<List<Map<String, dynamic>>> getApplicationsForProperty(int propertyId) async {
    final apps = await getList('applications');
    final filtered = apps.where((a) => a['propertyId'] == propertyId).cast<Map<String, dynamic>>().toList();
    return filtered;
  }

  Future<int> addApplication(int locataireId, int propertyId, String message) async {
    final apps = await getList('applications');
    final allProps = await getProperties(status: null);
    final property = allProps.firstWhere((p) => p.id == propertyId);
    final newId = apps.isEmpty ? 1 : (apps.last['id'] as int) + 1;
    apps.add({
      'id': newId,
      'locataireId': locataireId,
      'propertyId': propertyId,
      'message': message,
      'statut': 'en_attente',
      'date': DateTime.now().toIso8601String(),
      'bien': property.titre,
      'lieu': property.lieu,
      'prix': property.prix,
      'proprietaireId': property.proprietaireId,
      'visiteDate': null,
      'visiteHeure': null,
    });
    await setList('applications', apps);
    
    // Notification au propriétaire
    await addNotification(property.proprietaireId, 'Nouvelle candidature', 'Vous avez reçu une nouvelle candidature pour "${property.titre}"', 'candidature');
    
    _triggerSync();
    return newId;
  }

  Future<int> updateApplicationStatus(int appId, String status, {DateTime? visiteDate, String? visiteHeure}) async {
    final apps = await getList('applications');
    final index = apps.indexWhere((a) => a['id'] == appId);
    if (index == -1) return 0;
    
    final appData = apps[index];
    appData['statut'] = status;
    if (visiteDate != null) appData['visiteDate'] = visiteDate.toIso8601String();
    if (visiteHeure != null) appData['visiteHeure'] = visiteHeure;
    await setList('applications', apps);

    // Notification au locataire
    final locataireId = appData['locataireId'] as int;
    final bienTitle = appData['bien'] as String;
    String title = '';
    String body = '';

    if (status == 'acceptee' && visiteDate != null) {
      title = 'Visite planifiée';
      body = 'Le propriétaire a planifié une visite pour "$bienTitle" le ${DateFormat('dd/MM/yyyy').format(visiteDate)} à $visiteHeure.';
    } else if (status == 'acceptee') {
      title = 'Candidature acceptée';
      body = 'Félicitations ! Votre candidature pour "$bienTitle" a été acceptée.';
    } else if (status == 'refusee') {
      title = 'Candidature refusée';
      body = 'Désolé, votre candidature pour "$bienTitle" n\'a pas été retenue.';
    }

    if (title.isNotEmpty) {
      await addNotification(locataireId, title, body, 'candidature');
    }

    _triggerSync();
    return 1;
  }

  // ========== SIGNALEMENTS ==========
  Future<List<Map<String, dynamic>>> getAllReports() async {
    final list = await getList('reports');
    return list.cast<Map<String, dynamic>>();
  }

  Future<int> addReport(Map<String, dynamic> report) async {
    final reports = await getList('reports');
    final newId = reports.isEmpty ? 1 : (reports.last['id'] as int) + 1;
    report['id'] = newId;
    report['date'] = DateTime.now().toIso8601String();
    report['status'] = 'en_attente';
    reports.add(report);
    await setList('reports', reports);
    
    // Increment report count on property if applicable
    if (report['propertyId'] != null) {
      final propertyId = report['propertyId'] as int;
      final props = await getProperties(status: null);
      final index = props.indexWhere((p) => p.id == propertyId);
      if (index != -1) {
        final updated = props[index].toMap();
        updated['reports'] = (updated['reports'] as int? ?? 0) + 1;
        final updatedList = List.from(props.map((p) => p.toMap()));
        updatedList[index] = updated;
        await setList('properties', updatedList);
      }
    }
    
    _triggerSync();
    return newId;
  }

  Future<int> updateReportStatus(int reportId, String status) async {
    final reports = await getList('reports');
    final index = reports.indexWhere((r) => r['id'] == reportId);
    if (index == -1) return 0;
    reports[index]['status'] = status;
    await setList('reports', reports);
    return 1;
  }

  // ========== ÉVALUATIONS ==========
  Future<List<Map<String, dynamic>>> getReviewsForUser(int targetId) async {
    final reviews = await getList('reviews');
    return reviews.where((r) => r['targetId'] == targetId).cast<Map<String, dynamic>>().toList();
  }

  Future<int> addReview(Map<String, dynamic> review) async {
    final reviews = await getList('reviews');
    final newId = reviews.isEmpty ? 1 : (reviews.last['id'] as int) + 1;
    review['id'] = newId;
    review['date'] = DateTime.now().toIso8601String();
    reviews.add(review);
    await setList('reviews', reviews);
    
    // Mettre à jour la note moyenne de l'utilisateur
    final userReviews = reviews.where((r) => r['targetId'] == review['targetId']).toList();
    if (userReviews.isNotEmpty) {
      final avgRating = userReviews.map((r) => r['rating'] as num).fold(0.0, (a, b) => a + b) / userReviews.length;
      await updateUser(review['targetId'], {'rating': avgRating, 'reviewCount': userReviews.length});
    }
    _triggerSync();
    return newId;
  }

  // ========== PARTENAIRES ==========
  Future<List<Map<String, dynamic>>> getAllPartners() async {
    final list = await getList('partners');
    return list.cast<Map<String, dynamic>>();
  }

  Future<int> addPartner(Map<String, dynamic> partner) async {
    final partners = await getList('partners');
    final newId = partners.isEmpty ? 1 : (partners.last['id'] as int) + 1;
    partner['id'] = newId;
    partners.add(partner);
    await setList('partners', partners);
    return newId;
  }

  // ========== SERVICE REQUESTS ==========
  Future<List<Map<String, dynamic>>> getServiceRequestsForUser(int userId) async {
    final list = await getList('service_requests');
    return list.where((r) => r['userId'] == userId).cast<Map<String, dynamic>>().toList();
  }

  Future<int> addServiceRequest(Map<String, dynamic> request) async {
    final list = await getList('service_requests');
    final newId = list.isEmpty ? 1 : (list.last['id'] as int) + 1;
    request['id'] = newId;
    request['date'] = DateTime.now().toIso8601String();
    request['status'] = 'en_attente';
    list.add(request);
    await setList('service_requests', list);
    _triggerSync();
    return newId;
  }

  Future<int> updatePartner(int id, Map<String, dynamic> data) async {
    final partners = await getList('partners');
    final index = partners.indexWhere((p) => p['id'] == id);
    if (index == -1) return 0;
    partners[index].addAll(data);
    await setList('partners', partners);
    return 1;
  }

  Future<int> deletePartner(int id) async {
    final partners = await getList('partners');
    partners.removeWhere((p) => p['id'] == id);
    await setList('partners', partners);
    return 1;
  }

  // ========== SERVICES PARTENAIRES ==========
  Future<List<Map<String, dynamic>>> getPartnerServices() async {
    final list = await getList('partner_services');
    return list.cast<Map<String, dynamic>>();
  }

  Future<int> addPartnerService(Map<String, dynamic> service) async {
    final services = await getPartnerServices();
    final newId = services.isEmpty ? 1 : (services.last['id'] as int) + 1;
    service['id'] = newId;
    service['createdAt'] = DateTime.now().toIso8601String();
    services.add(service);
    await setList('partner_services', services);
    return newId;
  }

  Future<int> updatePartnerService(int id, Map<String, dynamic> data) async {
    final services = await getPartnerServices();
    final index = services.indexWhere((s) => s['id'] == id);
    if (index == -1) return 0;
    services[index].addAll(data);
    await setList('partner_services', services);
    return 1;
  }

  Future<int> deletePartnerService(int id) async {
    final services = await getPartnerServices();
    services.removeWhere((s) => s['id'] == id);
    await setList('partner_services', services);
    return 1;
  }

  // ========== DEMANDES DE SERVICES ==========
  Future<List<Map<String, dynamic>>> getServiceRequestsForPartner(int partenaireId) async {
    final requests = await getList('service_requests');
    final services = await getPartnerServices();
    final serviceIds = services.where((s) => s['partenaireId'] == partenaireId).map((s) => s['id'] as int).toList();
    return requests.where((r) => serviceIds.contains(r['serviceId'])).cast<Map<String, dynamic>>().toList();
  }



  Future<int> updateServiceRequestStatus(int requestId, String status) async {
    final requests = await getList('service_requests');
    final index = requests.indexWhere((r) => r['id'] == requestId);
    if (index == -1) return 0;
    requests[index]['statut'] = status;
    await setList('service_requests', requests);
    return 1;
  }

  // ========== ABONNEMENTS ==========


  // ========== COMMISSIONS ==========
  Future<List<Map<String, dynamic>>> getCommissions() async {
    final list = await getList('commissions');
    return list.cast<Map<String, dynamic>>();
  }

  Future<int> addCommission(Map<String, dynamic> commission) async {
    final list = await getCommissions();
    final newId = list.isEmpty ? 1 : (list.last['id'] as int) + 1;
    commission['id'] = newId;
    commission['date'] = DateTime.now().toIso8601String();
    list.add(commission);
    await setList('commissions', list);
    return newId;
  }

  Future<double> calculateCommission(int userId, double amount) async {
    final user = await getUserById(userId);
    final isPremium = user?.subscriptionType == 'premium_plus';
    return amount * (isPremium ? 0.03 : 0.05);
  }

  Future<void> addCommissionRecord(Map<String, dynamic> record) async {
    final commissions = await getList('commissions');
    commissions.add(record);
    await setList('commissions', commissions);
  }

  // ========== CONTRACTS & DOCUMENTS ==========
  Future<List<Map<String, dynamic>>> getContractsForOwner(int ownerId) async {
    final docs = await getList('contracts');
    return docs.where((d) => d['proprietaireId'] == ownerId).cast<Map<String, dynamic>>().toList();
  }

  Future<int> addContract(Map<String, dynamic> data) async {
    final docs = await getList('contracts');
    final newId = docs.isEmpty ? 1 : (docs.last['id'] as int) + 1;
    data['id'] = newId;
    data['date'] = DateTime.now().toIso8601String();
    docs.add(data);
    await setList('contracts', docs);
    return newId;
  }

  // ========== NOTIFICATIONS ==========
  Future<List<Map<String, dynamic>>> getNotifications(int userId) async {
    final list = await getList('notifications');
    return list.where((n) => n['userId'] == userId).cast<Map<String, dynamic>>().toList();
  }

  Future<int> addNotification(int userId, String title, String body, String type) async {
    final notifs = await getList('notifications');
    final newId = notifs.isEmpty ? 1 : (notifs.last['id'] as int) + 1;
    notifs.add({
      'id': newId,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'read': false,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await setList('notifications', notifs);
    _triggerSync();
    return newId;
  }

  Future<int> markNotificationAsRead(int notifId) async {
    final notifs = await getList('notifications');
    final index = notifs.indexWhere((n) => n['id'] == notifId);
    if (index == -1) return 0;
    notifs[index]['read'] = true;
    await setList('notifications', notifs);
    return 1;
  }

  // ========== COMMUNAUTÉ ==========
  Future<List<Map<String, dynamic>>> getCommunityPosts() async {
    final list = await getList('community_posts');
    final posts = list.cast<Map<String, dynamic>>().toList();
    posts.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
    return posts;
  }

  Future<int> addCommunityPost(Map<String, dynamic> post) async {
    final posts = await getCommunityPosts();
    final newId = posts.isEmpty ? 1 : (posts.last['id'] as int) + 1;
    post['id'] = newId;
    post['date'] = DateTime.now().toIso8601String();
    post['comments'] = [];
    posts.add(post);
    await setList('community_posts', posts);
    return newId;
  }

  Future<int> addCommunityComment(int postId, Map<String, dynamic> comment) async {
    final posts = await getCommunityPosts();
    final index = posts.indexWhere((p) => p['id'] == postId);
    if (index == -1) return 0;
    final comments = List<Map<String, dynamic>>.from(posts[index]['comments'] as List? ?? []);
    final newId = comments.isEmpty ? 1 : (comments.last['id'] as int) + 1;
    comment['id'] = newId;
    comment['date'] = DateTime.now().toIso8601String();
    comments.add(comment);
    posts[index]['comments'] = comments;
    await setList('community_posts', posts);
    return 1;
  }

  Future<void> addCommunityReport({
    required int targetId,
    required String type, // 'post' or 'comment'
    required String reason,
    required String description,
    required String priority,
    required int reporterId,
  }) async {
    final reports = await getList('community_reports');
    final newId = reports.length + 1;
    reports.add({
      'id': newId,
      'targetId': targetId,
      'type': type,
      'reason': reason,
      'description': description,
      'priority': priority,
      'reporterId': reporterId,
      'date': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
    await setList('community_reports', reports);
  }

  // ========== SUPPRESSION GÉNÉRIQUE ==========
  Future<int> delete(String table, {required int id}) async {
    await _init();
    final String? data = _prefs.getString(table);
    if (data == null) return 0;
    List<dynamic> list = jsonDecode(data);
    list.removeWhere((item) => item['id'] == id);
    await _prefs.setString(table, jsonEncode(list));
    return 1;
  }

  // ========== KYC / VÉRIFICATION ==========
  Future<List<Map<String, dynamic>>> getKYCRequests({String? status}) async {
    await _init();
    List<User> allUsers = await getAllUsers();
    List<Map<String, dynamic>> kycRequests = [];
    
    for (var user in allUsers) {
      if (status == null || user.verificationStatus == status) {
        kycRequests.add({
          'userId': user.id,
          'nom': user.nom,
          'prenom': user.prenom,
          'email': user.email,
          'telephone': user.telephone,
          'role': user.role,
          'verificationStatus': user.verificationStatus ?? 'non_verifie',
          'verificationDocument': user.verificationDocument,
          'verificationDocumentAddress': user.verificationDocumentAddress,
          'verificationDocumentProperty': user.verificationDocumentProperty,
          'verificationDocumentType': user.verificationDocumentType,
          'verificationRejectionReason': user.verificationRejectionReason,
          'verificationApprovedAt': user.verificationApprovedAt?.toIso8601String(),
          'verificationApprovedBy': user.verificationApprovedBy,
        });
      }
    }
    return kycRequests;
  }

  Future<void> submitKYCDocument({
    required int userId, 
    String? identityPath, 
    String? addressPath, 
    String? propertyPath, 
    required String documentType,
    String? cniNumber,
    DateTime? expiryDate,
  }) async {
    await _init();
    User? user = await getUserById(userId);
    if (user == null) return;

    User updatedUser = user.copyWith(
      verificationDocument: identityPath,
      verificationDocumentAddress: addressPath,
      verificationDocumentProperty: propertyPath,
      verificationDocumentType: documentType,
      verificationStatus: 'en_attente',
      cniNumber: cniNumber,
      documentExpiryDate: expiryDate,
    );
    await updateUser(user.id, updatedUser.toMap());
  }

  Future<void> approveKYC(int userId, int adminId) async {
    await _init();
    User? user = await getUserById(userId);
    if (user == null) return;

    User updatedUser = user.copyWith(
      verificationStatus: 'certifie',
      verificationApprovedAt: DateTime.now(),
      verificationApprovedBy: adminId.toString(),
      kycBadgeVisible: true,

    );
    await updateUser(user.id, updatedUser.toMap());
  }

  Future<void> rejectKYC(int userId, String rejectionReason) async {
    await _init();
    User? user = await getUserById(userId);
    if (user == null) return;

    User updatedUser = user.copyWith(
      verificationStatus: 'rejet',
      verificationRejectionReason: rejectionReason,
      verificationDocument: null,
      kycBadgeVisible: false,

    );
    await updateUser(user.id, updatedUser.toMap());
  }

  Future<User?> getKYCRequestForUser(int userId) async {
    return await getUserById(userId);
  }

  // ========== KYC DOCUMENTS (PHASE 2) ==========
  Future<List<dynamic>> _getKYCDocumentsList() async {
    return await getList('kyc_documents');
  }

  Future<void> _setKYCDocumentsList(List<dynamic> list) async {
    await setList('kyc_documents', list);
  }

  Future<List<dynamic>> getUserKYCDocuments(int userId) async {
    final docs = await _getKYCDocumentsList();
    return docs.where((doc) => doc['user_id'] == userId).toList();
  }

  Future<void> addKYCDocument(dynamic document) async {
    final docs = await _getKYCDocumentsList();
    final newDoc = document is Map ? document : document.toJson();
    docs.add(newDoc);
    await _setKYCDocumentsList(docs);
  }

  Future<void> updateKYCDocumentStatus(
    int documentId,
    String newStatus, {
    String? rejectionReason,
    int? verifiedBy,
    DateTime? verifiedAt,
  }) async {
    final docs = await _getKYCDocumentsList();
    final index = docs.indexWhere((doc) => doc['id'] == documentId);
    if (index != -1) {
      docs[index]['status'] = newStatus;
      if (rejectionReason != null) docs[index]['rejection_reason'] = rejectionReason;
      if (verifiedBy != null) docs[index]['verified_by'] = verifiedBy;
      if (verifiedAt != null) docs[index]['verified_at'] = verifiedAt.toIso8601String();
      await _setKYCDocumentsList(docs);
    }
  }

  // ========== REPORTS (PHASE 2) ==========
  Future<List<dynamic>> getAllReportsAdvanced({String? status, String? reportType}) async {
    final reports = await getList('reports');
    var filtered = reports;
    
    if (status != null) {
      filtered = filtered.where((r) => r['status'] == status).toList();
    }
    if (reportType != null) {
      filtered = filtered.where((r) => r['report_type'] == reportType).toList();
    }
    
    return filtered;
  }

  Future<void> addReportAdvanced(dynamic report) async {
    final reports = await getList('reports');
    final newReport = report is Map ? report : report.toJson();
    reports.add(newReport);
    await setList('reports', reports);
  }

  Future<void> updateReportStatusAdvanced(int reportId, String newStatus, {String? adminNotes, int? actionTaken}) async {
    final reports = await getList('reports');
    final index = reports.indexWhere((r) => r['id'] == reportId);
    if (index != -1) {
      reports[index]['status'] = newStatus;
      if (adminNotes != null) reports[index]['admin_notes'] = adminNotes;
      if (actionTaken != null) reports[index]['action_taken'] = actionTaken;
      reports[index]['date_resolved'] = DateTime.now().toIso8601String();
      await setList('reports', reports);
    }
  }

  // ========== ADMIN SANCTIONS (PHASE 2) ==========
  Future<List<dynamic>> getAllSanctions({bool? active}) async {
    final sanctions = await getList('admin_sanctions');
    var filtered = sanctions;
    
    if (active != null) {
      filtered = filtered.where((s) => (s['is_active'] ?? false) == active).toList();
    }
    
    return filtered;
  }

  Future<List<dynamic>> getUserSanctions(int userId) async {
    final sanctions = await getList('admin_sanctions');
    return sanctions.where((s) => s['user_id'] == userId).toList();
  }

  Future<void> addSanction(dynamic sanction) async {
    final sanctions = await getList('admin_sanctions');
    final newSanction = sanction is Map ? sanction : sanction.toJson();
    sanctions.add(newSanction);
    await setList('admin_sanctions', sanctions);
  }

  Future<void> updateSanctionStatus(int sanctionId, String newStatus) async {
    final sanctions = await getList('admin_sanctions');
    final index = sanctions.indexWhere((s) => s['id'] == sanctionId);
    if (index != -1) {
      sanctions[index]['status'] = newStatus;
      await setList('admin_sanctions', sanctions);
    }
  }

  Future<void> expireSanction(int sanctionId) async {
    final sanctions = await getList('admin_sanctions');
    final index = sanctions.indexWhere((s) => s['id'] == sanctionId);
    if (index != -1) {
      sanctions[index]['is_active'] = false;
      await setList('admin_sanctions', sanctions);
    }
  }

  // ========== COMMISSION RECORDS (PHASE 2) ==========
  Future<List<dynamic>> getAllCommissionRecords({String? status}) async {
    final records = await getList('commission_records');
    var filtered = records;
    
    if (status != null) {
      filtered = filtered.where((r) => r['status'] == status).toList();
    }
    
    return filtered;
  }

  Future<List<dynamic>> getUserCommissions(int userId) async {
    final records = await getList('commission_records');
    return records.where((r) => r['user_id'] == userId).toList();
  }

  Future<double> getUserTotalCommissions(int userId) async {
    final commissions = await getUserCommissions(userId);
    return commissions.fold<double>(0.0, (sum, r) => sum + ((r['amount'] ?? 0.0) as num).toDouble());
  }



  Future<void> updateCommissionStatus(int recordId, String newStatus, {DateTime? dateCredited}) async {
    final records = await getList('commission_records');
    final index = records.indexWhere((r) => r['id'] == recordId);
    if (index != -1) {
      records[index]['status'] = newStatus;
      if (dateCredited != null) records[index]['date_credited'] = dateCredited.toIso8601String();
      await setList('commission_records', records);
    }
  }

  // ========== PROPRIÉTÉS AMÉLIORÉES ==========
  Future<List<Map<String, dynamic>>> getAllProperties() async {
    final list = await getList('properties');
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getPropertyStats(int propertyId) async {
    final stats = await getList('property_stats');
    try {
      return stats.firstWhere((s) => s['property_id'] == propertyId) as Map<String, dynamic>;
    } catch (_) {
      // Créer des stats par défaut
      final defaultStats = {
        'property_id': propertyId,
        'total_views': 0,
        'this_month_views': 0,
        'application_count': 0,
        'active_application_count': 0,
        'average_rating': 0.0,
        'rating_count': 0,
        'last_updated': DateTime.now().toIso8601String(),
      };
      return defaultStats;
    }
  }

  Future<void> incrementPropertyViews(int propertyId) async {
    final stats = await getList('property_stats');
    var index = stats.indexWhere((s) => s['property_id'] == propertyId);
    
    if (index != -1) {
      stats[index]['total_views'] = (stats[index]['total_views'] ?? 0) + 1;
      stats[index]['this_month_views'] = (stats[index]['this_month_views'] ?? 0) + 1;
      stats[index]['last_updated'] = DateTime.now().toIso8601String();
    } else {
      stats.add({
        'property_id': propertyId,
        'total_views': 1,
        'this_month_views': 1,
        'application_count': 0,
        'active_application_count': 0,
        'average_rating': 0.0,
        'rating_count': 0,
        'last_updated': DateTime.now().toIso8601String(),
      });
    }
    await setList('property_stats', stats);
  }

  Future<void> updatePropertyAdvanced(Property property) async {
    final props = await getAllProperties();
    final index = props.indexWhere((p) => p['id'] == property.id);
    if (index != -1) {
      props[index] = property.toMap();
      await setList('properties', props);
    }
  }

  Future<void> addPropertyAdvanced(Property property) async {
    final props = await getAllProperties();
    props.add(property.toMap());
    await setList('properties', props);
  }

  Future<void> deletePropertyAdvanced(int propertyId) async {
    final props = await getAllProperties();
    props.removeWhere((p) => p['id'] == propertyId);
    await setList('properties', props);
  }

  // ========== CANDIDATURES AMÉLIORÉES ==========
  Future<List<Map<String, dynamic>>> getApplicationsByProperty(int propertyId) async {
    final apps = await getList('applications');
    return apps.where((a) => a['property_id'] == propertyId).cast<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getApplicationsByTenant(int tenantId) async {
    final apps = await getList('applications');
    return apps.where((a) => a['tenant_id'] == tenantId).cast<Map<String, dynamic>>().toList();
  }

  Future<void> addApplicationAdvanced(Application application) async {
    final apps = await getList('applications');
    apps.add(application.toJson());
    await setList('applications', apps);
  }

  Future<void> updateApplicationStatusAdvanced(int applicationId, String status) async {
    final apps = await getList('applications');
    final index = apps.indexWhere((a) => a['id'] == applicationId);
    if (index != -1) {
      apps[index]['status'] = status;
      await setList('applications', apps);
    }
  }

  // ========== VISITES PLANIFIÉES ==========
  Future<void> addScheduledVisit(ScheduledVisit visit) async {
    final visits = await getList('scheduled_visits');
    visits.add(visit.toJson());
    await setList('scheduled_visits', visits);
  }

  Future<List<Map<String, dynamic>>> getScheduledVisitsByProperty(int propertyId) async {
    final visits = await getList('scheduled_visits');
    return visits.where((v) => v['property_id'] == propertyId).cast<Map<String, dynamic>>().toList();
  }

  Future<void> updateVisitStatus(int visitId, String status) async {
    final visits = await getList('scheduled_visits');
    final index = visits.indexWhere((v) => v['id'] == visitId);
    if (index != -1) {
      visits[index]['status'] = status;
      if (status == 'completed') {
        visits[index]['completed_at'] = DateTime.now().toIso8601String();
      }
      await setList('scheduled_visits', visits);
    }
  }

  // ========== ÉTAT DES LIEUX ==========
  Future<void> addUtilityInspection(UtilityInspection inspection) async {
    final inspections = await getList('utility_inspections');
    inspections.add(inspection.toJson());
    await setList('utility_inspections', inspections);
  }

  Future<List<Map<String, dynamic>>> getUtilityInspections(int contractId) async {
    final inspections = await getList('utility_inspections');
    return inspections.where((i) => i['contract_id'] == contractId).cast<Map<String, dynamic>>().toList();
  }

  // ========== ABONNEMENTS ==========
  Future<Map<String, dynamic>?> getCurrentSubscription(int userId) async {
    final subs = await getList('subscriptions');
    try {
      return subs.firstWhere(
        (s) => s['user_id'] == userId && (s['is_active'] ?? false),
      ) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getSubscriptionHistory(int userId) async {
    final subs = await getList('subscriptions');
    return subs.where((s) => s['user_id'] == userId).cast<Map<String, dynamic>>().toList();
  }

  Future<void> createSubscription(Subscription subscription) async {
    final subs = await getList('subscriptions');
    subs.add(subscription.toJson());
    await setList('subscriptions', subs);
  }

  Future<void> deactivateSubscription(int subscriptionId) async {
    final subs = await getList('subscriptions');
    final index = subs.indexWhere((s) => s['id'] == subscriptionId);
    if (index != -1) {
      subs[index]['is_active'] = false;
      await setList('subscriptions', subs);
    }
  }

  Future<void> cancelSubscription(int subscriptionId) async {
    final subs = await getList('subscriptions');
    final index = subs.indexWhere((s) => s['id'] == subscriptionId);
    if (index != -1) {
      subs[index]['is_active'] = false;
      subs[index]['date_cancelled'] = DateTime.now().toIso8601String();
      await setList('subscriptions', subs);
    }
  }

  // ========== CONTRATS ==========
  Future<List<Map<String, dynamic>>> getContractsByTenant(int tenantId) async {
    final contracts = await getList('contracts');
    return contracts.where((c) => c['locataire_id'] == tenantId).cast<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getContractsByOwner(int ownerId) async {
    final contracts = await getList('contracts');
    return contracts.where((c) => c['proprietaire_id'] == ownerId).cast<Map<String, dynamic>>().toList();
  }



  // ========== ÉVALUATIONS ==========
  Future<List<Map<String, dynamic>>> getEvaluationsReceived(int userId) async {
    final evals = await getList('evaluations');
    return evals.where((e) => e['evalu_id'] == userId).cast<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getEvaluationsGiven(int userId) async {
    final evals = await getList('evaluations');
    return evals.where((e) => e['evaluateur_id'] == userId).cast<Map<String, dynamic>>().toList();
  }

  Future<void> addEvaluation(Evaluation evaluation) async {
    final evals = await getList('evaluations');
    evals.add(evaluation.toJson());
    await setList('evaluations', evals);
  }

  Future<void> updateEvaluation(Evaluation evaluation) async {
    final evals = await getList('evaluations');
    final index = evals.indexWhere((e) => e['id'] == evaluation.id);
    if (index != -1) {
      evals[index] = evaluation.toJson();
      await setList('evaluations', evals);
    }
  }

  Future<void> deleteEvaluation(int evaluationId) async {
    final evals = await getList('evaluations');
    evals.removeWhere((e) => e['id'] == evaluationId);
    await setList('evaluations', evals);
  }

  // ========== TRANSACTIONS / PAIEMENTS ==========
  Future<List<Map<String, dynamic>>> getTransactionsByLocataire(int locataireId) async {
    final trans = await getList('transactions');
    return trans.where((t) => t['locataire_id'] == locataireId).cast<Map<String, dynamic>>().toList();
  }

  Future<void> addTransaction(Transaction transaction) async {
    final trans = await getList('transactions');
    trans.add(transaction.toJson());
    await setList('transactions', trans);
  }

  // ============================================================
  // LOGS & SYSTEM SETTINGS (Mocked)
  // ============================================================

  Future<void> addLog({int? userId, required String action, required String details, String type = 'system'}) async {
    final logs = await getList('logs');
    final newLog = {
      'id': logs.length + 1,
      'userId': userId,
      'action': action,
      'details': details,
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
    };
    logs.insert(0, newLog);
    await setList('logs', logs);
  }

  Future<List<Map<String, dynamic>>> getLogs({String? type}) async {
    final logs = await getList('logs');
    final mappedLogs = logs.cast<Map<String, dynamic>>().toList();
    if (type != null) {
      return mappedLogs.where((l) => l['type'] == type).toList();
    }
    return mappedLogs;
  }

  Future<List<Map<String, dynamic>>> getAllSettings() async {
    final settings = await getList('settings');
    if (settings.isEmpty) {
      // Retourner les valeurs par défaut si vide
      return [
        {'key': 'platform_name', 'value': 'Immo Bénin', 'description': 'Nom de la plateforme', 'group_name': 'general'},
        {'key': 'support_email', 'value': 'support@immobenin.bj', 'description': 'Email du support', 'group_name': 'general'},
        {'key': 'commission_rate', 'value': '5', 'description': 'Taux de commission normal (%)', 'group_name': 'finance'},
        {'key': 'commission_rate_premium', 'value': '3', 'description': 'Taux commission Premium+ (%)', 'group_name': 'finance'},
        {'key': 'premium_price', 'value': '25000', 'description': 'Prix mensuel Premium+ (FCFA)', 'group_name': 'finance'},
        {'key': 'max_free_listings', 'value': '5', 'description': 'Max biens (Gratuit)', 'group_name': 'limits'},
        {'key': 'max_photos_per_listing', 'value': '10', 'description': 'Max photos par annonce', 'group_name': 'limits'},
        {'key': 'report_threshold', 'value': '5', 'description': 'Seuil de signalements pour suspension', 'group_name': 'moderation'},
        {'key': 'push_notifications', 'value': 'true', 'description': 'Activer notifications push', 'group_name': 'notifications'},
        {'key': 'app_maintenance', 'value': 'false', 'description': 'Mode maintenance', 'group_name': 'general'},
      ];
    }
    return settings.cast<Map<String, dynamic>>().toList();
  }

  Future<void> updateSetting(String key, String value) async {
    final settings = await getAllSettings();
    final index = settings.indexWhere((s) => s['key'] == key);
    if (index != -1) {
      settings[index]['value'] = value;
      await setList('settings', settings);
    }
  }

  Future<String?> getSetting(String key) async {
    final settings = await getAllSettings();
    try {
      return settings.firstWhere((s) => s['key'] == key)['value'] as String;
    } catch (_) {
      return null;
    }
  }



  // ========== MESSAGERIE ==========

  Future<List<Map<String, dynamic>>> getMessages(int userId1, int userId2) async {
    final list = await getList('messages');
    return list.where((m) => 
      (m['senderId'] == userId1 && m['receiverId'] == userId2) ||
      (m['senderId'] == userId2 && m['receiverId'] == userId1)
    ).cast<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getConversations(int userId) async {
    final list = await getList('messages');
    final Map<int, Map<String, dynamic>> conversations = {};

    for (var m in list) {
      final senderId = m['senderId'] as int;
      final receiverId = m['receiverId'] as int;

      if (senderId == userId || receiverId == userId) {
        final otherUserId = senderId == userId ? receiverId : senderId;
        final timestamp = DateTime.tryParse(m['timestamp'].toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);

        if (!conversations.containsKey(otherUserId)) {
          conversations[otherUserId] = {
            'otherUserId': otherUserId,
            'lastMessage': m,
            'timestamp': timestamp,
          };
        } else {
          final existingTimestamp = conversations[otherUserId]!['timestamp'] as DateTime;
          if (timestamp.isAfter(existingTimestamp)) {
            conversations[otherUserId] = {
              'otherUserId': otherUserId,
              'lastMessage': m,
              'timestamp': timestamp,
            };
          }
        }
      }
    }

    final sortedConversations = conversations.values.toList()
      ..sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    final result = <Map<String, dynamic>>[];
    for (var conv in sortedConversations) {
      final otherUserId = conv['otherUserId'] as int;
      final user = await getUserById(otherUserId);
      if (user != null) {
        result.add({
          'user': user,
          'lastMessage': conv['lastMessage'],
          'timestamp': conv['timestamp'],
        });
      }
    }

    return result;
  }

  Future<int> addMessage(Map<String, dynamic> messageData) async {
    final messages = await getList('messages');
    final newId = messages.isEmpty ? 1 : (messages.last['id'] as int) + 1;
    messageData['id'] = newId;
    messageData['timestamp'] = messageData['timestamp'] ?? DateTime.now().toIso8601String();
    messages.add(messageData);
    await setList('messages', messages);
    _triggerSync();
    return newId;
  }

  Future<int> markMessagesAsRead(int senderId, int receiverId) async {
    final messages = await getList('messages');
    int updatedCount = 0;
    for (var m in messages) {
      if (m['senderId'] == senderId && m['receiverId'] == receiverId && m['read'] != true) {
        m['read'] = true;
        m['readAt'] = DateTime.now().toIso8601String();
        updatedCount++;
      }
    }
    if (updatedCount > 0) {
      await setList('messages', messages);
      _triggerSync();
    }
    return updatedCount;
  }

  // ========== SOCIAL INTERACTIONS ==========
  Future<void> likeProperty(int propertyId) async {
    final props = await getProperties(status: null);
    final index = props.indexWhere((p) => p.id == propertyId);
    if (index != -1) {
      final updated = props[index].toMap();
      updated['likes'] = (updated['likes'] as int? ?? 0) + 1;
      final updatedList = List.from(props.map((p) => p.toMap()));
      updatedList[index] = updated;
      await setList('properties', updatedList);
    }
  }

  Future<void> dislikeProperty(int propertyId) async {
    final props = await getProperties(status: null);
    final index = props.indexWhere((p) => p.id == propertyId);
    if (index != -1) {
      final updated = props[index].toMap();
      updated['dislikes'] = (updated['dislikes'] as int? ?? 0) + 1;
      final updatedList = List.from(props.map((p) => p.toMap()));
      updatedList[index] = updated;
      await setList('properties', updatedList);
    }
  }

  Future<void> addComment(int propertyId, int userId, String userName, String text) async {
    final comments = await getList('comments');
    final newId = comments.length + 1;
    comments.add({
      'id': newId,
      'propertyId': propertyId,
      'userId': userId,
      'userName': userName,
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await setList('comments', comments);
    _triggerSync();
    
    // Update property comment count
    final props = await getProperties(status: null);
    final index = props.indexWhere((p) => p.id == propertyId);
    if (index != -1) {
      final updated = props[index].toMap();
      updated['commentsCount'] = (updated['commentsCount'] as int? ?? 0) + 1;
      final updatedList = List.from(props.map((p) => p.toMap()));
      updatedList[index] = updated;
      await setList('properties', updatedList);
    }
  }

  Future<List<Map<String, dynamic>>> getComments(int propertyId) async {
    final list = await getList('comments');
    return list.where((c) => c['propertyId'] == propertyId).cast<Map<String, dynamic>>().toList();
  }

  Future<void> reserveProperty(int propertyId) async {
    final props = await getProperties(status: null);
    final index = props.indexWhere((p) => p.id == propertyId);
    if (index != -1) {
      final updated = props[index].toMap();
      updated['isReserved'] = 1;
      updated['status'] = 'suspendu'; // Automatically deactivate for others
      final updatedList = List.from(props.map((p) => p.toMap()));
      updatedList[index] = updated;
      await setList('properties', updatedList);
      _triggerSync();
    }
  }


  // ========== SUPPORT TICKETS ==========
  Future<List<Map<String, dynamic>>> getTickets() async {
    final list = await getList('tickets');
    return list.cast<Map<String, dynamic>>();
  }

  Future<int> addTicket(Map<String, dynamic> ticket) async {
    final tickets = await getTickets();
    final newId = tickets.isEmpty ? 1 : (tickets.last['id'] as int) + 1;
    ticket['id'] = newId;
    ticket['createdAt'] = DateTime.now().toIso8601String();
    ticket['status'] = 'ouvert';
    tickets.add(ticket);
    await setList('tickets', tickets);
    _triggerSync();
    return newId;
  }

  Future<int> updateTicket(int id, Map<String, dynamic> data) async {
    final tickets = await getTickets();
    final index = tickets.indexWhere((t) => t['id'] == id);
    if (index == -1) return 0;
    tickets[index].addAll(data);
    await setList('tickets', tickets);
    return 1;
  }
}
