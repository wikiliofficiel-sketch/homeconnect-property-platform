import 'package:flutter/foundation.dart';
import '../models/extended_models.dart';
import '../services/database_helper.dart';

class SanctionProvider extends ChangeNotifier {
  List<AdminSanction> _sanctions = [];
  AdminSanction? _currentSanction;
  bool _isLoading = false;
  String _error = '';
  String _successMessage = '';

  List<AdminSanction> get sanctions => _sanctions;
  AdminSanction? get currentSanction => _currentSanction;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get successMessage => _successMessage;

  /// Charger toutes les sanctions
  Future<void> loadAllSanctions({bool? active}) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final db = DatabaseHelper();
      final rawSanctions = await db.getAllSanctions(active: active);
      
      _sanctions = rawSanctions
          .map((s) => AdminSanction.fromJson(s as Map<String, dynamic>))
          .toList();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement des sanctions: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger les sanctions d'un utilisateur
  Future<void> loadUserSanctions(int userId) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final db = DatabaseHelper();
      final rawSanctions = await db.getUserSanctions(userId);
      
      _sanctions = rawSanctions
          .map((s) => AdminSanction.fromJson(s as Map<String, dynamic>))
          .toList();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Appliquer une sanction
  Future<bool> applySanction({
    required int userId,
    required String sanctionType, // 'warning', 'suspension', 'permanent_ban', 'content_removal'
    required String reason,
    String? details,
    int? reportId,
    required int adminId,
    int? suspensionDays, // Pour les suspensions temporaires
  }) async {
    _isLoading = true;
    _error = '';
    _successMessage = '';
    notifyListeners();

    try {
      DateTime? expiresAt;
      if (sanctionType == 'suspension' && suspensionDays != null) {
        expiresAt = DateTime.now().add(Duration(days: suspensionDays));
      }

      final db = DatabaseHelper();
      final newSanction = AdminSanction(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: userId,
        sanctionType: sanctionType,
        reason: reason,
        details: details,
        reportId: reportId,
        appliedBy: adminId,
        appliedAt: DateTime.now(),
        duration: sanctionType == 'suspension' && suspensionDays != null
            ? Duration(days: suspensionDays)
            : null,
        expiresAt: expiresAt,
        isActive: true,
      );

      await db.addSanction(newSanction);
      _successMessage = 'Sanction appliquée avec succès';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Erreur lors de l\'application: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Vérifier si un utilisateur a une sanction active
  bool userHasActiveSanction(int userId) {
    return _sanctions.any(
      (s) => s.userId == userId && s.isActive && !s.isExpired,
    );
  }

  /// Obtenir la sanction active d'un utilisateur
  AdminSanction? getUserActiveSanction(int userId) {
    try {
      return _sanctions.firstWhere(
        (s) => s.userId == userId && s.isActive && !s.isExpired,
      );
    } catch (_) {
      return null;
    }
  }

  /// Vérifier si l'utilisateur est banni définitivement
  bool isPermanentlyBanned(int userId) {
    return _sanctions.any(
      (s) => s.userId == userId && 
             s.sanctionType == 'permanent_ban' && 
             s.isActive,
    );
  }

  /// Vérifier si l'utilisateur est actuellement suspendu
  bool isSuspended(int userId) {
    final activeSanction = getUserActiveSanction(userId);
    return activeSanction != null && activeSanction.sanctionType == 'suspension';
  }

  /// Lever une sanction
  Future<bool> removeSanction(int sanctionId) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final db = DatabaseHelper();
      await db.updateSanctionStatus(sanctionId, 'lifted');
      await db.expireSanction(sanctionId);

      await loadAllSanctions();
      _isLoading = false;
      _successMessage = 'Sanction levée avec succès';
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Erreur lors de la levée: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Gérer les appels de suspension
  Future<bool> handleAppeal({
    required int sanctionId,
    required String decision, // 'approved', 'denied'
    String? notes,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final index = _sanctions.indexWhere((s) => s.id == sanctionId);
      if (index != -1) {
        // Mettre à jour le statut d'appel
        // Pour l'instant on va via updateSanctionStatus
        if (decision == 'approved') {
          await removeSanction(sanctionId);
        }
      }

      await loadAllSanctions();
      _isLoading = false;
      _successMessage = 'Appel traité';
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Erreur lors du traitement: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Obtenir les statistiques des sanctions
  Map<String, dynamic> getSanctionStats() {
    final active = _sanctions.where((s) => s.isActive && !s.isExpired).length;
    final expired = _sanctions.where((s) => s.isExpired).length;
    final bans = _sanctions.where((s) => s.sanctionType == 'permanent_ban' && s.isActive).length;
    final suspensions = _sanctions.where((s) => s.sanctionType == 'suspension' && s.isActive && !s.isExpired).length;
    final warnings = _sanctions.where((s) => s.sanctionType == 'warning' && s.isActive).length;

    return {
      'totalSanctions': _sanctions.length,
      'activeSanctions': active,
      'expiredSanctions': expired,
      'permanentBans': bans,
      'activeSuspensions': suspensions,
      'warnings': warnings,
    };
  }

  /// Renouveler une sanction
  Future<bool> renewSanction({
    required int sanctionId,
    required int newDurationDays,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final db = DatabaseHelper();
      final sanction = _sanctions.firstWhere((s) => s.id == sanctionId);
      
      final newSanction = AdminSanction(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: sanction.userId,
        sanctionType: sanction.sanctionType,
        reason: '${sanction.reason} (Renouvelée)',
        details: sanction.details,
        reportId: sanction.reportId,
        appliedBy: sanction.appliedBy,
        appliedAt: DateTime.now(),
        duration: Duration(days: newDurationDays),
        expiresAt: DateTime.now().add(Duration(days: newDurationDays)),
        isActive: true,
      );

      await db.addSanction(newSanction);
      await loadAllSanctions();
      _isLoading = false;
      _successMessage = 'Sanction renouvelée';
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Erreur lors du renouvellement: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Vérifier et expirer automatiquement les sanctions
  Future<void> checkAndExpireSanctions() async {
    try {
      final db = DatabaseHelper();
      final toExpire = _sanctions.where((s) => s.isExpired && s.isActive).toList();
      
      for (final sanction in toExpire) {
        await db.expireSanction(sanction.id);
      }

      if (toExpire.isNotEmpty) {
        await loadAllSanctions();
      }
    } catch (e) {
      _error = 'Erreur lors de la vérification: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Effacer les messages
  void clearMessages() {
    _error = '';
    _successMessage = '';
    notifyListeners();
  }
}
