import 'package:flutter/material.dart';
import '../models/property.dart';
import '../models/locataire_models.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../models/report_sanction_models.dart';

/// Provider pour la recherche avancée de propriétés
class SearchProvider extends ChangeNotifier {
  final List<Property> _searchResults = [];
  final SearchFilter _currentFilter = const SearchFilter();
  bool _isLoading = false;
  String _error = '';

  List<Property> get searchResults => _searchResults;
  SearchFilter get currentFilter => _currentFilter;
  bool get isLoading => _isLoading;
  String get error => _error;

  final List<String> villes = [
    'Cotonou',
    'Porto-Novo',
    'Parakou',
    'Bohicon',
    'Abomey',
    'Natitingou',
    'Kaédi',
  ];

  final List<String> typesBien = [
    'Appartement',
    'Maison',
    'Villa',
    'Studio',
    'Bureau',
  ];

  /// Search properties with filters
  Future<void> searchProperties({
    String? ville,
    String? typeBien,
    int? prixMin,
    int? prixMax,
    int? piecesMin,
    int? piecesMax,
    bool verifiedOnly = false,
    bool photosOnly = false,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // Appel API → même BDD que le web
      final raw = await ApiService.getProperties();
      final allProperties = raw
          .map((p) => Property.fromApiMap(Map<String, dynamic>.from(p)))
          .toList();

      _searchResults.clear();

      for (final prop in allProperties) {
        if (ville != null && ville.isNotEmpty && !prop.ville.toLowerCase().contains(ville.toLowerCase()) && !prop.lieu.toLowerCase().contains(ville.toLowerCase())) continue;
        if (typeBien != null && typeBien.isNotEmpty && prop.type != typeBien) continue;
        if (prixMin != null && prop.prix < prixMin) continue;
        if (prixMax != null && prop.prix > prixMax) continue;
        if (piecesMin != null && prop.pieces < piecesMin) continue;
        if (piecesMax != null && prop.pieces > piecesMax) continue;
        if (verifiedOnly && !prop.verified) continue;

        _searchResults.add(prop);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur recherche: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reset filters and results
  void resetFilters() {
    _searchResults.clear();
    notifyListeners();
  }
}

/// Provider pour la communauté
class CommunityProvider extends ChangeNotifier {
  final List<CommunityPost> _posts = [];
  bool _isLoading = false;
  String _error = '';
  String _successMessage = '';

  List<CommunityPost> get posts => _posts;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get successMessage => _successMessage;

  /// Load community posts
  Future<void> loadPosts() async {
    _isLoading = true;
    _error = '';
    _successMessage = '';
    notifyListeners();

    try {
      final db = DatabaseHelper();
      final rawPosts = await db.getList('community_posts');

      _posts.clear();
      for (final raw in rawPosts) {
        _posts.add(CommunityPost.fromJson(raw));
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur chargement posts: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new post
  Future<void> addPost({
    required int userId,
    required String userName,
    required String userAvatar,
    required String contenu,
  }) async {
    try {
      final newPost = CommunityPost(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        contenu: contenu,
        dateCreation: DateTime.now(),
        likes: 0,
        commentsCount: 0,
        liked: false,
        comments: [],
      );

      final db = DatabaseHelper();
      final posts = await db.getList('community_posts');
      posts.add(newPost.toJson());
      await db.setList('community_posts', posts);

      _posts.insert(0, newPost);
      _successMessage = 'Post créé avec succès';
      notifyListeners();
    } catch (e) {
      _error = 'Erreur création post: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Add comment to post
  Future<void> addComment({
    required int postId,
    required int userId,
    required String userName,
    required String contenu,
  }) async {
    try {
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex == -1) return;

      final post = _posts[postIndex];
      final newComment = CommentItem(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: userId,
        userName: userName,
        contenu: contenu,
        dateCreation: DateTime.now(),
      );

      final updatedComments = [...post.comments, newComment];
      final updatedPost = CommunityPost(
        id: post.id,
        userId: post.userId,
        userName: post.userName,
        userAvatar: post.userAvatar,
        contenu: post.contenu,
        dateCreation: post.dateCreation,
        likes: post.likes,
        commentsCount: updatedComments.length,
        liked: post.liked,
        comments: updatedComments,
      );

      _posts[postIndex] = updatedPost;
      notifyListeners();
      
      // 🔔 Envoyer une notification automatique à l'auteur du post
      if (post.userId != userId) {
        await NotificationService.addNotification(
          userId: post.userId,
          title: 'Nouveau commentaire',
          body: '$userName a commenté sur votre post',
          type: 'comment_received',
        );
      }
    } catch (e) {
      _error = 'Erreur ajout commentaire: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Toggle like on post
  Future<void> toggleLike(int postId) async {
    try {
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex == -1) return;

      final post = _posts[postIndex];
      final updatedPost = CommunityPost(
        id: post.id,
        userId: post.userId,
        userName: post.userName,
        userAvatar: post.userAvatar,
        contenu: post.contenu,
        dateCreation: post.dateCreation,
        likes: post.liked ? post.likes - 1 : post.likes + 1,
        commentsCount: post.commentsCount,
        liked: !post.liked,
        comments: post.comments,
      );

      _posts[postIndex] = updatedPost;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur like: ${e.toString()}';
      notifyListeners();
    }
  }
}

/// Provider pour les signalements du locataire
class TenantReportProvider extends ChangeNotifier {
  final List<Report> _reports = [];
  bool _isLoading = false;
  String _error = '';
  String _successMessage = '';

  List<Report> get reports => _reports;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get successMessage => _successMessage;

  /// Load user reports
  Future<void> loadUserReports(int userId) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final db = DatabaseHelper();
      final rawReports = await db.getList('reports');

      _reports.clear();
      for (final raw in rawReports) {
        if (raw['reporter_id'] == userId) {
          _reports.add(Report.fromJson(raw));
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur chargement: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submit a report
  Future<bool> submitReport({
    required int reporterId,
    required String type, // 'property', 'user', 'comment'
    required int targetId,
    required String motif,
    required String description,
    required String priorite,
  }) async {
    try {
      final newReport = Report(
        id: DateTime.now().millisecondsSinceEpoch,
        reporterId: reporterId,
        targetUserId: targetId, // Simplifié pour le test, peut être targetPropertyId selon le cas
        targetPropertyId: type == 'property' ? targetId : null,
        type: ReportType.other, // Valeur par défaut pour compatibilité
        priority: priorite == 'haute' ? ReportPriority.high : ReportPriority.medium,
        status: ReportStatus.open,
        title: motif,
        description: description,
        attachmentUrls: [],
        createdAt: DateTime.now(),
        hasEscalated: false,
      );

      final db = DatabaseHelper();
      final reports = await db.getList('reports');
      reports.add(newReport.toJson());
      await db.setList('reports', reports);

      _reports.add(newReport);
      _successMessage = 'Signalement envoyé avec succès';
      notifyListeners();

      return true;
    } catch (e) {
      _error = 'Erreur submission: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
}
