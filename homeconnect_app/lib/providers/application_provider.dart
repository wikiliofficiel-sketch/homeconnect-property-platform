import 'package:flutter/foundation.dart';
import '../models/extended_models.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';

class ApplicationProvider extends ChangeNotifier {
  List<Application> _applications = [];
  List<ScheduledVisit> _scheduledVisits = [];
  bool _isLoading = false;
  String _error = '';
  String _successMessage = '';

  List<Application> get applications => _applications;
  List<ScheduledVisit> get scheduledVisits => _scheduledVisits;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get successMessage => _successMessage;

  // Stats
  int get pendingCount => _applications.where((a) => a.status == 'pending').length;
  int get approvedCount => _applications.where((a) => a.status == 'approved').length;
  int get rejectedCount => _applications.where((a) => a.status == 'rejected').length;

  /// Charger les candidatures d'une propriété
  Future<void> loadApplicationsByProperty(int propertyId) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final db = DatabaseHelper();
      final rawApplications = await db.getApplicationsByProperty(propertyId);
      
      _applications = rawApplications
          .map((a) => Application.fromJson(a))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger les candidatures d'un locataire
  Future<void> loadApplicationsByTenant(int tenantId) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final db = DatabaseHelper();
      final rawApplications = await db.getApplicationsByTenant(tenantId);
      
      _applications = rawApplications
          .map((a) => Application.fromJson(a))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Soumettre une candidature
  Future<bool> submitApplication({
    required int propertyId,
    required int tenantId,
    String? coverLetter,
    List<String>? documents,
  }) async {
    _isLoading = true;
    _error = '';
    _successMessage = '';
    notifyListeners();

    try {
      final newApplication = Application(
        id: DateTime.now().millisecondsSinceEpoch,
        propertyId: propertyId,
        tenantId: tenantId,
        status: 'pending',
        coverLetter: coverLetter,
        documents: documents,
        dateCreation: DateTime.now(),
      );

      final db = DatabaseHelper();
      await db.addApplication(tenantId, propertyId, coverLetter ?? '');

      _applications.add(newApplication);
      _successMessage = 'Candidature soumise avec succès';
      _isLoading = false;
      notifyListeners();

      // Déclencher la synchronisation automatique vers Symfony
      SyncService.autoSync();

      return true;
    } catch (e) {
      _error = 'Erreur lors de la soumission: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Approuver une candidature
  Future<bool> approveApplication({
    required int applicationId,
    required int ownerId,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final index = _applications.indexWhere((a) => a.id == applicationId);
      if (index == -1) {
        _error = 'Candidature non trouvée';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final oldApp = _applications[index];
      final updatedApp = Application(
        id: oldApp.id,
        propertyId: oldApp.propertyId,
        tenantId: oldApp.tenantId,
        status: 'approved',
        coverLetter: oldApp.coverLetter,
        documents: oldApp.documents,
        proposedRent: oldApp.proposedRent,
        dateCreation: oldApp.dateCreation,
        dateProcessed: DateTime.now(),
        processedBy: ownerId,
        rejectionReason: null,
      );

      final db = DatabaseHelper();
      await db.updateApplicationStatus(applicationId, 'approved');

      _applications[index] = updatedApp;
      _successMessage = 'Candidature approuvée';
      _isLoading = false;
      notifyListeners();
      
      // 🔔 Envoyer une notification automatique au locataire
      await NotificationService.addNotification(
        userId: oldApp.tenantId,
        title: 'Candidature acceptée !',
        body: 'Votre candidature pour le bien immobilier a été acceptée. Contactez le propriétaire pour planifier une visite.',
        type: 'application_approved',
      );
      
      return true;
    } catch (e) {
      _error = 'Erreur: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Rejeter une candidature
  Future<bool> rejectApplication({
    required int applicationId,
    required int ownerId,
    String? rejectionReason,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final index = _applications.indexWhere((a) => a.id == applicationId);
      if (index == -1) {
        _error = 'Candidature non trouvée';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final oldApp = _applications[index];
      final updatedApp = Application(
        id: oldApp.id,
        propertyId: oldApp.propertyId,
        tenantId: oldApp.tenantId,
        status: 'rejected',
        coverLetter: oldApp.coverLetter,
        documents: oldApp.documents,
        proposedRent: oldApp.proposedRent,
        dateCreation: oldApp.dateCreation,
        dateProcessed: DateTime.now(),
        processedBy: ownerId,
        rejectionReason: rejectionReason,
      );

      final db = DatabaseHelper();
      await db.updateApplicationStatus(applicationId, 'rejected');

      _applications[index] = updatedApp;
      _successMessage = 'Candidature refusée';
      _isLoading = false;
      notifyListeners();
      
      // 🔔 Envoyer une notification automatique au locataire
      await NotificationService.addNotification(
        userId: oldApp.tenantId,
        title: 'Candidature refusée',
        body: rejectionReason ?? 'Votre candidature pour ce bien a été refusée. Continuez à explorer d\'autres propriétés.',
        type: 'application_rejected',
      );
      
      return true;
    } catch (e) {
      _error = 'Erreur: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Planifier une visite
  Future<bool> scheduleVisit({
    required int applicationId,
    required int propertyId,
    required int tenantId,
    required int ownerId,
    required DateTime visitDate,
    String? notes,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final newVisit = ScheduledVisit(
        id: DateTime.now().millisecondsSinceEpoch,
        applicationId: applicationId,
        propertyId: propertyId,
        tenantId: tenantId,
        ownerId: ownerId,
        scheduledDate: visitDate,
        notes: notes,
        status: 'scheduled',
        dateCreation: DateTime.now(),
      );

      final db = DatabaseHelper();
      await db.addScheduledVisit(newVisit);

      _scheduledVisits.add(newVisit);
      _successMessage = 'Visite planifiée avec succès';
      _isLoading = false;
      notifyListeners();
      
      // 🔔 Envoyer une notification automatique au locataire
      await NotificationService.addNotification(
        userId: tenantId,
        title: 'Visite planifiée',
        body: 'Une visite a été planifiée pour ${visitDate.day}/${visitDate.month}/${visitDate.year} à ${visitDate.hour}:${visitDate.minute.toString().padLeft(2, '0')}',
        type: 'visit_scheduled',
      );
      
      return true;
    } catch (e) {
      _error = 'Erreur lors de la planification: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Charger les visites planifiées
  Future<void> loadScheduledVisits(int propertyId) async {
    try {
      final db = DatabaseHelper();
      final rawVisits = await db.getScheduledVisitsByProperty(propertyId);
      
      _scheduledVisits = rawVisits
          .map((v) => ScheduledVisit.fromJson(v))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Erreur chargement visites: ${e.toString()}');
    }
  }

  /// Marquer une visite comme terminée
  Future<bool> completeVisit(int visitId) async {
    try {
      final index = _scheduledVisits.indexWhere((v) => v.id == visitId);
      if (index == -1) return false;

      final visit = _scheduledVisits[index];
      final completedVisit = ScheduledVisit(
        id: visit.id,
        applicationId: visit.applicationId,
        propertyId: visit.propertyId,
        tenantId: visit.tenantId,
        ownerId: visit.ownerId,
        scheduledDate: visit.scheduledDate,
        notes: visit.notes,
        status: 'completed',
        completedAt: DateTime.now(),
        dateCreation: visit.dateCreation,
      );

      final db = DatabaseHelper();
      await db.updateVisitStatus(visitId, 'completed');

      _scheduledVisits[index] = completedVisit;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Erreur complétion visite: ${e.toString()}');
      return false;
    }
  }

  /// Mettre à jour le statut d'une visite
  Future<void> updateVisitStatus(int visitId, String status) async {
    try {
      final index = _scheduledVisits.indexWhere((v) => v.id == visitId);
      if (index == -1) return;

      final visit = _scheduledVisits[index];
      final updatedVisit = ScheduledVisit(
        id: visit.id,
        applicationId: visit.applicationId,
        propertyId: visit.propertyId,
        tenantId: visit.tenantId,
        ownerId: visit.ownerId,
        scheduledDate: visit.scheduledDate,
        status: status,
        notes: visit.notes,
        dateCreation: visit.dateCreation,
        completedAt: status == 'completed' ? DateTime.now() : visit.completedAt,
      );

      final db = DatabaseHelper();
      await db.updateVisitStatus(visitId, status);

      _scheduledVisits[index] = updatedVisit;
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur mise à jour visite: ${e.toString()}');
    }
  }

  void clearMessages() {
    _error = '';
    _successMessage = '';
    notifyListeners();
  }
}
