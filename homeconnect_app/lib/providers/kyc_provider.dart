import 'package:flutter/foundation.dart';
import '../models/kyc_models.dart';
import '../services/database_helper.dart';

/// Provider pour gérer le workflow KYC complet
class KYCProvider extends ChangeNotifier {
  final db = DatabaseHelper();

  // État
  List<KYCVerification> _verifications = [];
  KYCVerification? _currentVerification;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<KYCVerification> get verifications => _verifications;
  KYCVerification? get currentVerification => _currentVerification;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Statistiques
  int get totalVerifications => _verifications.length;
  int get verifiedCount =>
      _verifications.where((v) => v.status == KYCStatus.verified).length;
  int get pendingCount =>
      _verifications.where((v) => v.status == KYCStatus.pending).length;
  int get rejectedCount =>
      _verifications.where((v) => v.status == KYCStatus.rejected).length;

  // Initialiser une nouvelle vérification KYC
  Future<void> initializeKYC(
      int userId, String email, String? phoneNumber) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final verification = KYCVerification(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: userId,
        userEmail: email,
        userPhoneNumber: phoneNumber,
        status: KYCStatus.pending,
        documents: [],
        selfies: [],
        createdAt: DateTime.now(),
        attemptCount: 1,
      );

      _currentVerification = verification;
      _verifications.add(verification);

      // Sauvegarder en base de données
      await db.setList(
          'kyc_verifications', _verifications.map((v) => v.toJson()).toList());

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur initialisation KYC: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Ajouter un document d'identité
  Future<bool> addDocument({
    required int userId,
    required DocumentType type,
    required String documentNumber,
    required String frontImageUrl,
    required String backImageUrl,
    required DateTime issueDate,
    required DateTime expiryDate,
    required String issuingCountry,
    required String fullName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_currentVerification == null) {
        throw Exception('Aucune vérification KYC en cours');
      }

      final document = KYCDocument(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: userId,
        type: type,
        documentNumber: documentNumber,
        frontImageUrl: frontImageUrl,
        backImageUrl: backImageUrl,
        issueDate: issueDate,
        expiryDate: expiryDate,
        issuingCountry: issuingCountry,
        fullName: fullName,
        uploadedAt: DateTime.now(),
        isExpired: expiryDate.isBefore(DateTime.now()),
      );

      _currentVerification!.documents.add(document);

      // Mettre à jour le statut si document valide
      if (document.isValid && _currentVerification!.documents.isNotEmpty) {
        _currentVerification = _currentVerification!;
      }

      await _saveVerification(_currentVerification!);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur ajout document: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Ajouter une vérification de selfie
  Future<bool> addSelfieVerification({
    required int userId,
    required String imageUrl,
    required SelfieVerificationType type,
    required double? livenessScore,
    required double? faceDetectionScore,
    required double? qualityScore,
    required bool? faceMatched,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_currentVerification == null) {
        throw Exception('Aucune vérification KYC en cours');
      }

      // Vérifier qualité minimum
      final qualityScoreVal = qualityScore ?? 0;
      final livenessScoreVal = livenessScore ?? 0;

      final isApproved = qualityScoreVal >= 0.7 &&
          livenessScoreVal >= 0.8 &&
          (faceMatched ?? false);

      final selfie = SelfieVerification(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: userId,
        imageUrl: imageUrl,
        uploadedAt: DateTime.now(),
        verificationType: isApproved
            ? SelfieVerificationType.approved
            : SelfieVerificationType.rejected,
        livenessScore: livenessScore,
        faceDetectionScore: faceDetectionScore,
        qualityScore: qualityScore,
        faceMatched: faceMatched,
        isApproved: isApproved,
      );

      _currentVerification!.selfies.add(selfie);

      await _saveVerification(_currentVerification!);

      _isLoading = false;
      notifyListeners();
      return isApproved;
    } catch (e) {
      _errorMessage = 'Erreur vérification selfie: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Soumettre la vérification pour révision
  Future<bool> submitForReview(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_currentVerification == null) {
        throw Exception('Aucune vérification KYC en cours');
      }

      // Vérifier que documents et selfies sont présents
      if (_currentVerification!.documents.isEmpty ||
          _currentVerification!.selfies.isEmpty) {
        throw Exception('Documents et selfies requis');
      }

      // Mettre à jour le statut
      _currentVerification = KYCVerification(
        id: _currentVerification!.id,
        userId: _currentVerification!.userId,
        userEmail: _currentVerification!.userEmail,
        userPhoneNumber: _currentVerification!.userPhoneNumber,
        status: KYCStatus.needsReview,
        documents: _currentVerification!.documents,
        selfies: _currentVerification!.selfies,
        createdAt: _currentVerification!.createdAt,
        completedAt: _currentVerification!.completedAt,
        expiresAt: _currentVerification!.expiresAt,
        reviewedBy: _currentVerification!.reviewedBy,
        rejectionReason: _currentVerification!.rejectionReason,
        attemptCount: _currentVerification!.attemptCount,
      );

      // Mettre à jour dans la liste
      final index =
          _verifications.indexWhere((v) => v.id == _currentVerification!.id);
      if (index >= 0) {
        _verifications[index] = _currentVerification!;
      }

      await _saveVerifications();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur soumission: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Charger une vérification par ID utilisateur
  Future<void> loadUserVerification(int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final verifications =
          _verifications.where((v) => v.userId == userId).toList();
      if (verifications.isNotEmpty) {
        _currentVerification = verifications.first;
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur chargement: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Charger toutes les vérifications
  Future<void> loadAllVerifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await db.getList('kyc_verifications');
      _verifications = data
          .map((v) => KYCVerification.fromJson(v as Map<String, dynamic>))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur chargement vérifications: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Supprimer un document
  Future<bool> removeDocument(int documentId) async {
    try {
      if (_currentVerification == null) return false;

      _currentVerification!.documents.removeWhere((d) => d.id == documentId);
      await _saveVerification(_currentVerification!);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur suppression document: $e';
      notifyListeners();
      return false;
    }
  }

  // Supprimer une vérification de selfie
  Future<bool> removeSelfie(int selfieId) async {
    try {
      if (_currentVerification == null) return false;

      _currentVerification!.selfies.removeWhere((s) => s.id == selfieId);
      await _saveVerification(_currentVerification!);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur suppression selfie: $e';
      notifyListeners();
      return false;
    }
  }

  // === MÉTHODES ADMIN ===

  // Approuver une vérification KYC
  Future<bool> approveVerification(
      int verificationId, int adminId, String? notes) async {
    try {
      final index = _verifications.indexWhere((v) => v.id == verificationId);
      if (index < 0) return false;

      final oldVer = _verifications[index];
      final expiresAt = DateTime.now().add(const Duration(days: 365)); // Valide 1 an

      _verifications[index] = KYCVerification(
        id: oldVer.id,
        userId: oldVer.userId,
        userEmail: oldVer.userEmail,
        userPhoneNumber: oldVer.userPhoneNumber,
        status: KYCStatus.verified,
        documents: oldVer.documents,
        selfies: oldVer.selfies,
        createdAt: oldVer.createdAt,
        completedAt: DateTime.now(),
        expiresAt: expiresAt,
        reviewedBy: adminId,
        rejectionReason: null,
        attemptCount: oldVer.attemptCount,
      );

      await _saveVerifications();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur approbation: $e';
      notifyListeners();
      return false;
    }
  }

  // Rejeter une vérification KYC
  Future<bool> rejectVerification(
      int verificationId, int adminId, String reason) async {
    try {
      final index = _verifications.indexWhere((v) => v.id == verificationId);
      if (index < 0) return false;

      final oldVer = _verifications[index];

      _verifications[index] = KYCVerification(
        id: oldVer.id,
        userId: oldVer.userId,
        userEmail: oldVer.userEmail,
        userPhoneNumber: oldVer.userPhoneNumber,
        status: KYCStatus.rejected,
        documents: oldVer.documents,
        selfies: oldVer.selfies,
        createdAt: oldVer.createdAt,
        completedAt: DateTime.now(),
        expiresAt: oldVer.expiresAt,
        reviewedBy: adminId,
        rejectionReason: reason,
        attemptCount: oldVer.attemptCount + 1,
      );

      await _saveVerifications();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur rejet: $e';
      notifyListeners();
      return false;
    }
  }

  // Récupérer les vérifications en attente de révision
  List<KYCVerification> getPendingReviews() {
    return _verifications
        .where((v) => v.status == KYCStatus.needsReview)
        .toList();
  }

  // Récupérer les vérifications expirées
  List<KYCVerification> getExpiredVerifications() {
    return _verifications.where((v) {
      if (v.expiresAt == null) return false;
      return v.expiresAt!.isBefore(DateTime.now());
    }).toList();
  }

  /// Getter pour documents (pour compatibilité)
  List<KYCDocument> get documents {
    if (_currentVerification != null) {
      return _currentVerification!.documents;
    }
    return [];
  }

  /// Charger les documents d'un utilisateur
  Future<void> loadUserDocuments(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await loadUserVerification(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur chargement documents: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Approuver un document
  /// Approuver un document par son ID
  Future<bool> approveDocument({
    required int documentId,
    required int adminId,
    String? notes,
  }) async {
    try {
      // Chercher la vérification contenant ce document
      for (var verification in _verifications) {
        final docIndex =
            verification.documents.indexWhere((d) => d.id == documentId);
        if (docIndex != -1) {
          final doc = verification.documents[docIndex];
          // Marquer le document comme approuvé (mettre à jour verificationNotes)
          final updatedDoc = KYCDocument(
            id: doc.id,
            userId: doc.userId,
            type: doc.type,
            documentNumber: doc.documentNumber,
            frontImageUrl: doc.frontImageUrl,
            backImageUrl: doc.backImageUrl,
            issueDate: doc.issueDate,
            expiryDate: doc.expiryDate,
            issuingCountry: doc.issuingCountry,
            fullName: doc.fullName,
            uploadedAt: doc.uploadedAt,
            verificationNotes:
                'approved by admin $adminId${notes != null ? ': $notes' : ''}',
            isExpired: doc.isExpired,
          );
          verification.documents[docIndex] = updatedDoc;
          await _saveVerification(verification);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      _errorMessage = 'Erreur approbation document: $e';
      notifyListeners();
      return false;
    }
  }

  /// Rejeter un document par son ID
  Future<bool> rejectDocument({
    required int documentId,
    required int adminId,
    required String rejectionReason,
  }) async {
    try {
      // Chercher la vérification contenant ce document
      for (var verification in _verifications) {
        final docIndex =
            verification.documents.indexWhere((d) => d.id == documentId);
        if (docIndex != -1) {
          final doc = verification.documents[docIndex];
          // Marquer le document comme rejeté (mettre à jour verificationNotes)
          final updatedDoc = KYCDocument(
            id: doc.id,
            userId: doc.userId,
            type: doc.type,
            documentNumber: doc.documentNumber,
            frontImageUrl: doc.frontImageUrl,
            backImageUrl: doc.backImageUrl,
            issueDate: doc.issueDate,
            expiryDate: doc.expiryDate,
            issuingCountry: doc.issuingCountry,
            fullName: doc.fullName,
            uploadedAt: doc.uploadedAt,
            verificationNotes: 'rejected by admin $adminId: $rejectionReason',
            isExpired: doc.isExpired,
          );
          verification.documents[docIndex] = updatedDoc;
          await _saveVerification(verification);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      _errorMessage = 'Erreur rejet document: $e';
      notifyListeners();
      return false;
    }
  }

  // === HELPERS PRIVÉS ===

  Future<void> _saveVerification(KYCVerification verification) async {
    final index = _verifications.indexWhere((v) => v.id == verification.id);
    if (index >= 0) {
      _verifications[index] = verification;
    }
    await _saveVerifications();
  }

  Future<void> _saveVerifications() async {
    await db.setList(
        'kyc_verifications', _verifications.map((v) => v.toJson()).toList());
  }

  // Réinitialiser l'erreur
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
