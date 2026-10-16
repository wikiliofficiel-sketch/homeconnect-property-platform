import 'package:flutter/foundation.dart';
import '../models/report_sanction_models.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

/// Provider pour gérer les signalements et sanctions
class ReportProvider extends ChangeNotifier {
  final db = DatabaseHelper();

  List<Report> _reports = [];
  List<Sanction> _sanctions = [];
  final List<SanctionAppeal> _appeals = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Report> get reports => _reports;
  List<Sanction> get sanctions => _sanctions;
  List<SanctionAppeal> get appeals => _appeals;
  List<SanctionAppeal> get sanctionAppeals =>
      _appeals; // Alias pour compatibilité
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Statistiques
  int get openReportsCount =>
      _reports.where((r) => r.status == ReportStatus.open).length;
  int get inReviewCount =>
      _reports.where((r) => r.status == ReportStatus.inReview).length;
  int get approvedReportsCount =>
      _reports.where((r) => r.status == ReportStatus.approved).length;
  int get activeSanctionsCount =>
      _sanctions.where((s) => s.isCurrentlyActive).length;

  // === SIGNALEMENTS ===

  /// Créer un signalement
  Future<bool> submitReport({
    required int reporterId,
    required int targetUserId,
    required ReportType type,
    required String title,
    required String description,
    required List<String> attachments,
    int? targetPropertyId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final priority = _calculatePriority(type);

      final report = Report(
        id: DateTime.now().millisecondsSinceEpoch,
        reporterId: reporterId,
        targetUserId: targetUserId,
        targetPropertyId: targetPropertyId,
        type: type,
        priority: priority,
        status: ReportStatus.open,
        title: title,
        description: description,
        attachmentUrls: attachments,
        createdAt: DateTime.now(),
        hasEscalated: priority == ReportPriority.critical,
      );

      _reports.add(report);
      await _saveReports();

      _isLoading = false;
      notifyListeners();

      // 🔔 Envoyer une notification à l'utilisateur cible (optionnel)
      await NotificationService.addNotification(
        userId: targetUserId,
        title: 'Signalement déposé',
        body: 'Un signalement concernant votre activité a été enregistré.',
        type: 'report_target',
      );

      // 🔔 Notifier l'équipe administrative
      await NotificationService.addNotification(
        userId: 1, // Admin ID
        title: 'Nouveau signalement reçu',
        body: 'Le signalement "$title" nécessite une révision modération.',
        type: 'report_admin',
      );

      return true;
    } catch (e) {
      _errorMessage = 'Erreur soumission signalement: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Charger tous les signalements
  Future<void> loadAllReports() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await db.getList('reports');
      _reports = data
          .map((r) => Report.fromJson(r as Map<String, dynamic>))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur chargement signalements: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger les signalements d'un utilisateur
  Future<void> loadUserReports(int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await db.getList('reports');
      final allReports = data
          .map((r) => Report.fromJson(r as Map<String, dynamic>))
          .toList();
      _reports = allReports.where((r) => r.reporterId == userId).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur chargement: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger les signalements déposés contre un propriétaire (ou ses biens)
  Future<void> loadReportsAgainstOwner(int ownerId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final propertiesData = await db.getPropertiesForOwner(ownerId);
      final ownerPropertyIds = propertiesData.map((p) => p['id'] as int).toList();

      final data = await db.getList('reports');
      final allReports = data
          .map((r) => Report.fromJson(r as Map<String, dynamic>))
          .toList();

      _reports = allReports.where((r) => 
        r.targetUserId == ownerId || 
        (r.targetPropertyId != null && ownerPropertyIds.contains(r.targetPropertyId))
      ).toList();
      
      _reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur chargement: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ajouter une réponse du propriétaire ciblé
  Future<bool> addOwnerReply(int reportId, String reply) async {
    _isLoading = true;
    notifyListeners();

    try {
      final index = _reports.indexWhere((r) => r.id == reportId);
      if (index < 0) return false;

      final oldReport = _reports[index];

      _reports[index] = Report(
        id: oldReport.id,
        reporterId: oldReport.reporterId,
        targetUserId: oldReport.targetUserId,
        targetPropertyId: oldReport.targetPropertyId,
        type: oldReport.type,
        priority: oldReport.priority,
        status: oldReport.status,
        title: oldReport.title,
        description: oldReport.description,
        attachmentUrls: oldReport.attachmentUrls,
        createdAt: oldReport.createdAt,
        resolvedAt: oldReport.resolvedAt,
        reviewedBy: oldReport.reviewedBy,
        reviewNotes: oldReport.reviewNotes,
        hasEscalated: oldReport.hasEscalated,
        ownerReply: reply,
        ownerReplyAt: DateTime.now(),
      );

      await _saveReports();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur de réponse: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// === ADMIN: Gérer signalement ===

  /// Approuver un signalement et appliquer sanction
  Future<bool> approveReport(
    int reportId,
    int adminId,
    SanctionType sanctionType,
    String sanctionReason, {
    String? notes,
  }) async {
    try {
      final index = _reports.indexWhere((r) => r.id == reportId);
      if (index < 0) return false;

      final oldReport = _reports[index];

      // Mettre à jour le signalement
      _reports[index] = Report(
        id: oldReport.id,
        reporterId: oldReport.reporterId,
        targetUserId: oldReport.targetUserId,
        targetPropertyId: oldReport.targetPropertyId,
        type: oldReport.type,
        priority: oldReport.priority,
        status: ReportStatus.approved,
        title: oldReport.title,
        description: oldReport.description,
        attachmentUrls: oldReport.attachmentUrls,
        createdAt: oldReport.createdAt,
        resolvedAt: DateTime.now(),
        reviewedBy: adminId,
        reviewNotes: notes,
        hasEscalated: oldReport.hasEscalated,
        ownerReply: oldReport.ownerReply,
        ownerReplyAt: oldReport.ownerReplyAt,
      );

      // Créer la sanction automatiquement
      final sanction = Sanction(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: oldReport.targetUserId,
        type: sanctionType,
        reason: sanctionReason,
        appliedAt: DateTime.now(),
        expiresAt: _calculateSanctionExpiry(sanctionType),
        appliedBy: adminId,
        notes: notes,
        isActive: true,
        reportsCount: 1,
      );

      _sanctions.add(sanction);

      await _saveReports();
      await _saveSanctions();

      await db.addLog(
        userId: adminId,
        action: 'Sanction appliquée',
        details: 'Sanction "${sanctionType.toString().split('.').last}" appliquée à l\'utilisateur #${oldReport.targetUserId} pour "$sanctionReason".',
        type: 'modération',
      );

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur approbation: $e';
      notifyListeners();
      return false;
    }
  }

  /// Rejeter un signalement
  Future<bool> rejectReport(int reportId, int adminId, String reason) async {
    try {
      final index = _reports.indexWhere((r) => r.id == reportId);
      if (index < 0) return false;

      final oldReport = _reports[index];

      _reports[index] = Report(
        id: oldReport.id,
        reporterId: oldReport.reporterId,
        targetUserId: oldReport.targetUserId,
        targetPropertyId: oldReport.targetPropertyId,
        type: oldReport.type,
        priority: oldReport.priority,
        status: ReportStatus.rejected,
        title: oldReport.title,
        description: oldReport.description,
        attachmentUrls: oldReport.attachmentUrls,
        createdAt: oldReport.createdAt,
        resolvedAt: DateTime.now(),
        reviewedBy: adminId,
        reviewNotes: reason,
        hasEscalated: oldReport.hasEscalated,
        ownerReply: oldReport.ownerReply,
        ownerReplyAt: oldReport.ownerReplyAt,
      );

      await _saveReports();
      
      await db.addLog(
        userId: adminId,
        action: 'Signalement rejeté',
        details: 'Signalement #$reportId rejeté. Motif: $reason',
        type: 'modération',
      );

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur rejet: $e';
      notifyListeners();
      return false;
    }
  }

  /// Marquer signalement en révision
  Future<bool> startReview(int reportId, int adminId) async {
    try {
      final index = _reports.indexWhere((r) => r.id == reportId);
      if (index < 0) return false;

      final oldReport = _reports[index];

      _reports[index] = Report(
        id: oldReport.id,
        reporterId: oldReport.reporterId,
        targetUserId: oldReport.targetUserId,
        targetPropertyId: oldReport.targetPropertyId,
        type: oldReport.type,
        priority: oldReport.priority,
        status: ReportStatus.inReview,
        title: oldReport.title,
        description: oldReport.description,
        attachmentUrls: oldReport.attachmentUrls,
        createdAt: oldReport.createdAt,
        reviewedBy: adminId,
        hasEscalated: oldReport.hasEscalated,
        ownerReply: oldReport.ownerReply,
        ownerReplyAt: oldReport.ownerReplyAt,
      );

      await _saveReports();

      await db.addLog(
        userId: adminId,
        action: 'Révision commencée',
        details: 'Début de la révision pour le signalement #$reportId.',
        type: 'modération',
      );

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur: $e';
      notifyListeners();
      return false;
    }
  }

  /// === SANCTIONS ===

  /// Charger toutes les sanctions
  Future<void> loadAllSanctions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await db.getList('sanctions');
      _sanctions = data
          .map((s) => Sanction.fromJson(s as Map<String, dynamic>))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur chargement sanctions: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger les sanctions d'un utilisateur
  Future<void> loadUserSanctions(int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await db.getList('sanctions');
      final allSanctions = data
          .map((s) => Sanction.fromJson(s as Map<String, dynamic>))
          .toList();
      _sanctions = allSanctions.where((s) => s.userId == userId).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur chargement: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lever une sanction (expiration précoce)
  Future<bool> liftSanction(int sanctionId, int adminId, String reason) async {
    try {
      final index = _sanctions.indexWhere((s) => s.id == sanctionId);
      if (index < 0) return false;

      final oldSanction = _sanctions[index];

      _sanctions[index] = Sanction(
        id: oldSanction.id,
        userId: oldSanction.userId,
        type: oldSanction.type,
        reason: oldSanction.reason,
        appliedAt: oldSanction.appliedAt,
        expiresAt: DateTime.now(), // Expire maintenant
        appliedBy: oldSanction.appliedBy,
        notes: '${oldSanction.notes ?? ''}\nLevée par admin: $reason',
        isActive: false,
        reportsCount: oldSanction.reportsCount,
      );

      await _saveSanctions();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur levée sanction: $e';
      notifyListeners();
      return false;
    }
  }

  /// === APPELS DE SANCTION ===

  /// Créer un appel
  Future<bool> submitSanctionAppeal(
      int sanctionId, int userId, String reason) async {
    try {
      final appeal = SanctionAppeal(
        id: DateTime.now().millisecondsSinceEpoch,
        sanctionId: sanctionId,
        userId: userId,
        reason: reason,
        appealedAt: DateTime.now(),
      );

      _appeals.add(appeal);
      await _saveAppeals();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur soumission appel: $e';
      notifyListeners();
      return false;
    }
  }

  /// Approuver un appel
  Future<bool> approveAppeal(int appealId, int adminId, String notes) async {
    try {
      final index = _appeals.indexWhere((a) => a.id == appealId);
      if (index < 0) return false;

      final oldAppeal = _appeals[index];

      _appeals[index] = SanctionAppeal(
        id: oldAppeal.id,
        sanctionId: oldAppeal.sanctionId,
        userId: oldAppeal.userId,
        reason: oldAppeal.reason,
        appealedAt: oldAppeal.appealedAt,
        reviewedAt: DateTime.now(),
        reviewedBy: adminId,
        approved: true,
        adminNotes: notes,
      );

      // Lever la sanction
      await liftSanction(
          oldAppeal.sanctionId, adminId, 'Appel approuvé: $notes');

      await _saveAppeals();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur approbation appel: $e';
      notifyListeners();
      return false;
    }
  }

  /// Rejeter un appel
  Future<bool> rejectAppeal(int appealId, int adminId, String notes) async {
    try {
      final index = _appeals.indexWhere((a) => a.id == appealId);
      if (index < 0) return false;

      final oldAppeal = _appeals[index];

      _appeals[index] = SanctionAppeal(
        id: oldAppeal.id,
        sanctionId: oldAppeal.sanctionId,
        userId: oldAppeal.userId,
        reason: oldAppeal.reason,
        appealedAt: oldAppeal.appealedAt,
        reviewedAt: DateTime.now(),
        reviewedBy: adminId,
        approved: false,
        adminNotes: notes,
      );

      await _saveAppeals();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur rejet appel: $e';
      notifyListeners();
      return false;
    }
  }

  /// === PRIVÉ ===

  ReportPriority _calculatePriority(ReportType type) {
    switch (type) {
      case ReportType.scam:
      case ReportType.unsafeMeeting:
        return ReportPriority.critical;
      case ReportType.fraudulentListing:
      case ReportType.abusiveUser:
        return ReportPriority.high;
      case ReportType.inappropriateContent:
      case ReportType.discriminatory:
        return ReportPriority.medium;
      default:
        return ReportPriority.low;
    }
  }

  DateTime? _calculateSanctionExpiry(SanctionType type) {
    switch (type) {
      case SanctionType.warning:
        return null; // Pas d'expiration
      case SanctionType.suspension3Days:
        return DateTime.now().add(const Duration(days: 3));
      case SanctionType.suspension7Days:
        return DateTime.now().add(const Duration(days: 7));
      case SanctionType.suspension30Days:
        return DateTime.now().add(const Duration(days: 30));
      case SanctionType.banned:
        return null; // Permanent
    }
  }

  Future<void> _saveReports() async {
    await db.setList('reports', _reports.map((r) => r.toJson()).toList());
  }

  Future<void> _saveSanctions() async {
    await db.setList('sanctions', _sanctions.map((s) => s.toJson()).toList());
  }

  Future<void> _saveAppeals() async {
    await db.setList(
        'sanction_appeals', _appeals.map((a) => a.toJson()).toList());
  }

  /// Obtenir une sanction par son type
  Sanction? getSanctionByType(SanctionType type) {
    try {
      return _sanctions.firstWhere((s) => s.type == type);
    } catch (e) {
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
