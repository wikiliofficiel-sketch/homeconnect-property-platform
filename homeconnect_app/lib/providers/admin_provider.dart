import 'package:flutter/foundation.dart';
import '../services/database_helper.dart';

/// Provider pour gérer les données Admin Dashboard
class AdminProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  
  bool _isLoading = false;
  String _error = '';
  String _successMessage = '';

  // Stats
  int _totalUsers = 0;
  int _proprietaires = 0;
  int _locataires = 0;
  int _activeProperties = 0;
  int _totalReports = 0;
  final double _totalRevenue = 0;

  // Getters Stats
  bool get isLoading => _isLoading;
  String get error => _error;
  String get successMessage => _successMessage;
  int get totalUsers => _totalUsers;
  int get proprietaires => _proprietaires;
  int get locataires => _locataires;
  int get activeProperties => _activeProperties;
  int get totalReports => _totalReports;
  double get totalRevenue => _totalRevenue;

  /// Charge toutes les statistiques admin
  Future<void> loadDashboardStats() async {
    try {
      _isLoading = true;
      notifyListeners();

      _totalUsers = await _db.getTotalUsers();
      _proprietaires = await _db.getProprietairesCount();
      _locataires = await _db.getLocatairesCount();
      _activeProperties = await _db.getActivePropertiesCount();
      
      final reports = await _db.getList('reports');
      _totalReports = reports.length;

      _error = '';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur chargement stats: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charge les rapports/signalements en attente modération
  Future<List<Map<String, dynamic>>> loadReportsModerations() async {
    try {
      final reports = await _db.getList('reports');
      return reports
          .where((r) => r['statut'] == 'en_attente' || r['statut'] == 'signalé')
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      _error = 'Erreur: $e';
      return [];
    }
  }

  /// Approuve un signalement
  Future<void> approveReport(int reportId) async {
    try {
      final reports = await _db.getList('reports');
      final idx = reports.indexWhere((r) => r['id'] == reportId);
      if (idx != -1) {
        reports[idx]['statut'] = 'approuvé';
        await _db.setList('reports', reports);
        _successMessage = 'Signalement approuvé ✅';
        notifyListeners();
      }
    } catch (e) {
      _error = 'Erreur: $e';
      notifyListeners();
    }
  }

  /// Rejette un signalement
  Future<void> rejectReport(int reportId, String motif) async {
    try {
      final reports = await _db.getList('reports');
      final idx = reports.indexWhere((r) => r['id'] == reportId);
      if (idx != -1) {
        reports[idx]['statut'] = 'rejeté';
        reports[idx]['motifRejet'] = motif;
        await _db.setList('reports', reports);
        _successMessage = 'Signalement rejeté';
        notifyListeners();
      }
    } catch (e) {
      _error = 'Erreur: $e';
      notifyListeners();
    }
  }

  /// Bannit un utilisateur
  Future<void> banUser(int userId, String raison) async {
    try {
      final users = await _db.getList('users');
      final idx = users.indexWhere((u) => u['id'] == userId);
      if (idx != -1) {
        users[idx]['status'] = 'banni';
        users[idx]['banReason'] = raison;
        await _db.setList('users', users);
        _successMessage = 'Utilisateur banni ✅';
        notifyListeners();
      }
    } catch (e) {
      _error = 'Erreur: $e';
      notifyListeners();
    }
  }

  /// Débanni un utilisateur
  Future<void> unbanUser(int userId) async {
    try {
      final users = await _db.getList('users');
      final idx = users.indexWhere((u) => u['id'] == userId);
      if (idx != -1) {
        users[idx]['status'] = 'actif';
        users[idx]['banReason'] = null;
        await _db.setList('users', users);
        _successMessage = 'Utilisateur débanni ✅';
        notifyListeners();
      }
    } catch (e) {
      _error = 'Erreur: $e';
      notifyListeners();
    }
  }

  /// Vérifie une propriété
  Future<void> verifyProperty(int propertyId) async {
    try {
      final properties = await _db.getList('properties');
      final idx = properties.indexWhere((p) => p['id'] == propertyId);
      if (idx != -1) {
        properties[idx]['verified'] = true;
        await _db.setList('properties', properties);
        _successMessage = 'Propriété vérifiée ✅';
        notifyListeners();
      }
    } catch (e) {
      _error = 'Erreur: $e';
      notifyListeners();
    }
  }

  void clearMessages() {
    _error = '';
    _successMessage = '';
    notifyListeners();
  }
}
